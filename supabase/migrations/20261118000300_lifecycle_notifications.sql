-- =============================================================================
-- Migration: notifications across the incident lifecycle
--
-- Admins and operators get an in-app + push notification (through
-- write_notification, so notification_preferences apply and the push worker
-- delivers it) when:
--   1. a new incident is created from an alert   (create_incident_from_alert)
--   2. a remediation finishes, success or failed (complete_playbook_run)
--   3. a recovery check finishes                 (record_recovery_check)
--   4a. the postmortem is ready                  (save_postmortem, first save only)
--   4b. an incident is resolved                  (incident_status_event trigger)
--
-- Nobody is notified twice for one event: the person who acted (manual
-- completion, resolving the incident) is skipped, and for a finished
-- remediation the requester keeps the existing personal message and is
-- skipped in the broadcast.
-- Not notified: a repeated alert for an open incident, a 'pending' recovery
-- check, and a re-run of workflow 08 that updates an existing postmortem.
--
-- The five functions keep their signatures, checks and other side effects;
-- only the notification calls are new. CREATE OR REPLACE keeps their grants.
-- Rollback: database/rollback/20261118000300_lifecycle_notifications.down.sql
-- =============================================================================

-- 1. Internal helper -------------------------------------------------------------------
-- Like notify_approvers, but skips a list of users and trims the text to the
-- write_notification limits (title 200, message 2000).
CREATE FUNCTION public.notify_responders(p_skip uuid[], p_incident_id uuid, p_title text, p_message text)
RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_id uuid;
    v_skip uuid[] := array_remove(coalesce(p_skip, ARRAY[]::uuid[]), NULL);
BEGIN
    FOR v_id IN
        SELECT id FROM public.profiles
        WHERE role IN ('admin', 'operator') AND NOT (id = ANY (v_skip))
    LOOP
        PERFORM public.write_notification(v_id, p_incident_id, left(p_title, 200), left(p_message, 2000),
            ARRAY['in_app', 'push']);
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.notify_responders(uuid[], uuid, text, text) FROM PUBLIC, anon, authenticated;

-- 2. New incident ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_incident_from_alert(
    p_fingerprint text,
    p_title text,
    p_description text,
    p_severity text,
    p_service_name text,
    p_environment text DEFAULT NULL,
    p_detected_at timestamptz DEFAULT NULL
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_incident_id uuid;
    v_investigation_id uuid;
BEGIN
    PERFORM public.require_app_role(ARRAY['automation']);

    IF p_fingerprint IS NULL OR length(p_fingerprint) NOT BETWEEN 1 AND 200 THEN
        RAISE EXCEPTION 'A fingerprint of 1 to 200 characters is required.' USING ERRCODE = 'DC422';
    END IF;
    IF p_title IS NULL OR length(p_title) NOT BETWEEN 1 AND 300 THEN
        RAISE EXCEPTION 'A title of 1 to 300 characters is required.' USING ERRCODE = 'DC422';
    END IF;

    -- Serialize concurrent deliveries of the same alert.
    PERFORM pg_advisory_xact_lock(hashtext('incident_fingerprint:' || p_fingerprint));

    SELECT i.id INTO v_incident_id
      FROM public.incidents i
     WHERE i.alert_fingerprint = p_fingerprint AND i.status NOT IN ('resolved', 'closed')
     LIMIT 1;

    IF v_incident_id IS NOT NULL THEN
        SELECT inv.id INTO v_investigation_id
          FROM public.investigations inv
         WHERE inv.incident_id = v_incident_id
         ORDER BY inv.created_at DESC NULLS LAST
         LIMIT 1;
        RETURN jsonb_build_object('incident_id', v_incident_id, 'investigation_id', v_investigation_id,
                                  'created', false);
    END IF;

    -- severity is validated by incidents_severity_check.
    INSERT INTO public.incidents
        (title, description, severity, status, source, detected_at, service_name, environment, alert_fingerprint)
    VALUES
        (p_title, left(p_description, 4000), coalesce(p_severity, 'medium'), 'investigating', 'alertmanager',
         coalesce(p_detected_at, now()), left(p_service_name, 200), left(p_environment, 100), p_fingerprint)
    RETURNING id INTO v_incident_id;

    INSERT INTO public.investigations (incident_id, status)
    VALUES (v_incident_id, 'running')
    RETURNING id INTO v_investigation_id;

    PERFORM public.write_incident_event(v_incident_id, 'log', 'Incident created from alert',
        jsonb_build_object('source', 'alertmanager', 'investigation_id', v_investigation_id), 'warning');

    PERFORM public.notify_responders(NULL, v_incident_id,
        'New incident: ' || p_title,
        format('%s severity on %s. The investigation has started.',
               initcap(coalesce(p_severity, 'medium')), coalesce(left(p_service_name, 200), 'an unknown service')));

    RETURN jsonb_build_object('incident_id', v_incident_id, 'investigation_id', v_investigation_id,
                              'created', true);
END;
$$;

-- 3. Remediation finished ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.complete_playbook_run(
    p_run_id uuid,
    p_status text,
    p_result jsonb DEFAULT '{}'::jsonb,
    p_n8n_execution_id text DEFAULT NULL,
    p_reason text DEFAULT NULL
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['automation', 'operator', 'admin']);
    v_role text := public.current_app_role();
    v_result jsonb := public.redact_sensitive(coalesce(p_result, '{}'::jsonb));
    v_run public.playbook_runs%ROWTYPE;
    v_execution_id text;
    v_manual boolean := v_role <> 'automation';
BEGIN
    IF p_status IS NULL OR p_status NOT IN ('success', 'failed') THEN
        RAISE EXCEPTION 'Status must be success or failed.' USING ERRCODE = 'DC422';
    END IF;
    IF length(v_result::text) > 16000 THEN
        RAISE EXCEPTION 'Result too large (max 16 kB).' USING ERRCODE = 'DC422';
    END IF;
    IF p_reason IS NOT NULL AND length(p_reason) > 1000 THEN
        RAISE EXCEPTION 'Reason too long (max 1000).' USING ERRCODE = 'DC422';
    END IF;

    SELECT * INTO v_run FROM public.playbook_runs WHERE id = p_run_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Playbook run not found.' USING ERRCODE = 'DC404';
    END IF;
    IF v_run.status <> 'running' THEN
        RAISE EXCEPTION 'The run is %, not running.', v_run.status USING ERRCODE = 'DC409';
    END IF;

    IF v_manual THEN
        IF p_reason IS NULL OR length(btrim(p_reason)) < 5 THEN
            RAISE EXCEPTION 'A reason is required to complete a run manually.' USING ERRCODE = 'DC422';
        END IF;
    ELSE
        SELECT n8n_execution_id INTO v_execution_id
        FROM public.automation_runs WHERE id = v_run.automation_run_id;
        IF p_n8n_execution_id IS NULL OR v_execution_id IS DISTINCT FROM p_n8n_execution_id THEN
            RAISE EXCEPTION 'The execution id does not match this run.' USING ERRCODE = 'DC403';
        END IF;
    END IF;

    UPDATE public.playbook_runs
    SET status = p_status, completed_at = now(), result_payload = v_result,
        status_reason = p_reason, completed_by = v_uid
    WHERE id = p_run_id;

    UPDATE public.automation_runs
    SET status = p_status, completed_at = now(), output = v_result,
        error_message = CASE WHEN p_status = 'failed' THEN left(coalesce(v_result ->> 'error', p_reason), 500) END
    WHERE id = v_run.automation_run_id AND status = 'running';

    PERFORM public.log_audit_event(
        CASE WHEN v_manual THEN 'PLAYBOOK_RUN_COMPLETED_MANUALLY' ELSE 'PLAYBOOK_RUN_COMPLETED' END,
        'playbook_run', p_run_id,
        jsonb_build_object('incident_id', v_run.incident_id, 'status', p_status,
                           'n8n_execution_id', p_n8n_execution_id, 'reason', p_reason));
    PERFORM public.write_incident_event(v_run.incident_id, 'remediation',
        format('Remediation %s%s', p_status, CASE WHEN v_manual THEN ' (manual)' ELSE '' END),
        jsonb_build_object('playbook_run_id', p_run_id),
        CASE WHEN p_status = 'failed' THEN 'error' ELSE 'info' END);
    IF v_run.requested_by IS NOT NULL THEN
        PERFORM public.write_notification(v_run.requested_by, v_run.incident_id,
            format('Remediation %s', p_status), format('The remediation you requested finished: %s.', p_status),
            ARRAY['in_app', 'push']);
    END IF;
    -- Everyone else on the team (the requester got the message above; a person
    -- who completed the run manually does not need one).
    PERFORM public.notify_responders(ARRAY[v_run.requested_by, CASE WHEN v_manual THEN v_uid END],
        v_run.incident_id,
        CASE WHEN p_status = 'success' THEN 'Remediation succeeded' ELSE 'Remediation failed' END,
        format('The remediation on "%s" finished: %s.',
               (SELECT left(title, 200) FROM public.incidents WHERE id = v_run.incident_id), p_status));

    RETURN jsonb_build_object('run_id', p_run_id, 'status', p_status, 'manual', v_manual);
END;
$$;

-- 4. Recovery check finished -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.record_recovery_check(
    p_incident_id uuid,
    p_playbook_run_id uuid,
    p_status text,
    p_check_type text DEFAULT NULL,
    p_details jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['automation', 'operator', 'admin']);
    v_automation_run_id uuid;
    v_id uuid;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.incidents WHERE id = p_incident_id) THEN
        RAISE EXCEPTION 'Incident not found.' USING ERRCODE = 'DC404';
    END IF;
    IF p_playbook_run_id IS NOT NULL THEN
        SELECT automation_run_id INTO v_automation_run_id
        FROM public.playbook_runs WHERE id = p_playbook_run_id AND incident_id = p_incident_id;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'The playbook run does not belong to this incident.' USING ERRCODE = 'DC422';
        END IF;
    END IF;
    IF p_details IS NOT NULL AND (jsonb_typeof(p_details) <> 'object' OR length(p_details::text) > 16000) THEN
        RAISE EXCEPTION 'Details must be a JSON object (max 16 kB).' USING ERRCODE = 'DC422';
    END IF;

    -- status is validated by recovery_checks_status_check.
    INSERT INTO public.recovery_checks
        (incident_id, playbook_run_id, automation_run_id, status, check_type, details, checked_by)
    VALUES
        (p_incident_id, p_playbook_run_id, v_automation_run_id, p_status, left(p_check_type, 100),
         public.redact_sensitive(coalesce(p_details, '{}'::jsonb)), v_uid)
    RETURNING id INTO v_id;

    PERFORM public.log_audit_event('RECOVERY_CHECK_RECORDED', 'recovery_check', v_id,
        jsonb_build_object('incident_id', p_incident_id, 'playbook_run_id', p_playbook_run_id, 'status', p_status));
    PERFORM public.write_incident_event(p_incident_id, 'recovery', format('Recovery check: %s', p_status),
        jsonb_build_object('recovery_check_id', v_id, 'playbook_run_id', p_playbook_run_id),
        CASE WHEN p_status IN ('unhealthy', 'failed') THEN 'warning' ELSE 'info' END);

    -- A finished check only ('pending' is not a result yet).
    IF p_status IN ('healthy', 'unhealthy', 'failed') THEN
        PERFORM public.notify_responders(ARRAY[v_uid], p_incident_id,
            CASE WHEN p_status = 'healthy' THEN 'Recovered' ELSE 'Not recovered' END,
            format('Recovery check on "%s": %s.',
                   (SELECT left(title, 200) FROM public.incidents WHERE id = p_incident_id), p_status));
    END IF;

    RETURN v_id;
END;
$$;

-- 5. Postmortem ready ----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.save_postmortem(
    p_incident_id uuid,
    p_summary text,
    p_root_cause text,
    p_impact text,
    p_timeline jsonb,
    p_lessons_learned text,
    p_action_items jsonb,
    p_report jsonb
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_id uuid;
BEGIN
    PERFORM public.require_app_role(ARRAY['automation']);

    IF NOT EXISTS (SELECT 1 FROM public.incidents WHERE id = p_incident_id) THEN
        RAISE EXCEPTION 'Incident not found.' USING ERRCODE = 'DC404';
    END IF;
    IF p_summary IS NULL OR length(p_summary) NOT BETWEEN 1 AND 8000 THEN
        RAISE EXCEPTION 'A summary of 1 to 8000 characters is required.' USING ERRCODE = 'DC422';
    END IF;
    IF jsonb_typeof(coalesce(p_timeline, '[]'::jsonb)) <> 'array'
       OR jsonb_typeof(coalesce(p_action_items, '[]'::jsonb)) <> 'array' THEN
        RAISE EXCEPTION 'timeline and action_items must be JSON arrays.' USING ERRCODE = 'DC422';
    END IF;
    IF length(coalesce(p_report::text, '')) > 64000 THEN
        RAISE EXCEPTION 'Postmortem too large.' USING ERRCODE = 'DC422';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('postmortem:' || p_incident_id::text));

    -- One automation-written postmortem per incident (created_by NULL); a re-run updates it.
    SELECT p.id INTO v_id FROM public.postmortems p
     WHERE p.incident_id = p_incident_id AND p.created_by IS NULL
     ORDER BY p.created_at DESC LIMIT 1;

    IF v_id IS NULL THEN
        INSERT INTO public.postmortems
            (incident_id, summary, root_cause, impact, timeline, lessons_learned, action_items, report)
        VALUES
            (p_incident_id, p_summary, p_root_cause, p_impact, coalesce(p_timeline, '[]'::jsonb),
             p_lessons_learned, coalesce(p_action_items, '[]'::jsonb), p_report)
        RETURNING id INTO v_id;

        -- First save only; a re-run of workflow 08 updates the draft quietly.
        PERFORM public.notify_responders(NULL, p_incident_id, 'Postmortem ready',
            format('The postmortem for "%s" is ready to review.',
                   (SELECT left(title, 200) FROM public.incidents WHERE id = p_incident_id)));
    ELSE
        UPDATE public.postmortems
           SET summary = p_summary, root_cause = p_root_cause, impact = p_impact,
               timeline = coalesce(p_timeline, '[]'::jsonb), lessons_learned = p_lessons_learned,
               action_items = coalesce(p_action_items, '[]'::jsonb), report = p_report, updated_at = now()
         WHERE id = v_id;
    END IF;

    PERFORM public.write_incident_event(p_incident_id, 'comment', 'Postmortem draft saved',
        jsonb_build_object('postmortem_id', v_id));

    RETURN v_id;
END;
$$;

-- 6. Incident resolved ---------------------------------------------------------------------
-- Same trigger function as 20261107000800, plus the notification. Like the
-- timeline event, only for a change made by a signed-in user (not seed scripts
-- or SQL maintenance); that user is skipped.
CREATE OR REPLACE FUNCTION public.incident_status_event() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
    IF (SELECT auth.uid()) IS NOT NULL THEN
        PERFORM public.write_incident_event(NEW.id, 'status_change',
            format('Status %s -> %s', OLD.status, NEW.status),
            jsonb_build_object('from', OLD.status, 'to', NEW.status));
        IF NEW.status = 'resolved' THEN
            PERFORM public.notify_responders(ARRAY[(SELECT auth.uid())], NEW.id, 'Incident resolved',
                format('"%s" was resolved.', left(NEW.title, 200)));
        END IF;
    END IF;
    RETURN NULL;
END;
$$;
