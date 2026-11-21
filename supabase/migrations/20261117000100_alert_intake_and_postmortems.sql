-- =============================================================================
-- Migration: alert intake, AI analysis on investigations, and postmortems
-- Backend dependencies BD-1, BD-2 (follow-up) and BD-4
-- (docs/automation-integration-requirements.md, section 2).
--
--   BD-1  create_incident_from_alert: n8n workflow 01 creates an incident and
--         its investigation from an Alertmanager alert. Idempotent on the
--         alert fingerprint while the incident is still active, so a repeated
--         delivery (or concurrent duplicates, D-N8N-5) returns the same incident.
--   BD-2  record_ai_analysis now also completes the linked investigation
--         (the mobile root-cause screen reads public.investigations).
--   BD-4  get_incident_context (read incident, latest analysis, runs and
--         recovery checks) and save_postmortem (one automation postmortem per
--         incident, updated on a re-run).
--
-- All three functions are automation-only (A5); the backend calls them with
-- the automation identity after verifying the HMAC signature.
-- Rollback: database/rollback/20261117000100_alert_intake_and_postmortems.down.sql
-- =============================================================================

-- 1. Schema ------------------------------------------------------------------
ALTER TABLE public.incidents ADD COLUMN IF NOT EXISTS alert_fingerprint text;

-- One ACTIVE incident per alert fingerprint. A resolved/closed incident does
-- not block a new incident for the same alert firing again later.
CREATE UNIQUE INDEX IF NOT EXISTS incidents_active_alert_fingerprint_key
    ON public.incidents (alert_fingerprint)
    WHERE alert_fingerprint IS NOT NULL AND status NOT IN ('resolved', 'closed');

ALTER TABLE public.postmortems ADD COLUMN IF NOT EXISTS report jsonb;

-- 2. BD-1 ---------------------------------------------------------------------
CREATE FUNCTION public.create_incident_from_alert(
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

    RETURN jsonb_build_object('incident_id', v_incident_id, 'investigation_id', v_investigation_id,
                              'created', true);
END;
$$;

-- 3. BD-2 follow-up: complete the investigation with the AI result -------------
CREATE OR REPLACE FUNCTION public.record_ai_analysis(
    p_incident_id uuid,
    p_investigation_id uuid,
    p_model_name text,
    p_summary text,
    p_root_cause text,
    p_severity text,
    p_confidence numeric,
    p_evidence jsonb,
    p_recommended_action text
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
    IF p_investigation_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.investigations WHERE id = p_investigation_id AND incident_id = p_incident_id) THEN
        RAISE EXCEPTION 'The investigation does not belong to this incident.' USING ERRCODE = 'DC422';
    END IF;
    IF p_evidence IS NOT NULL AND jsonb_typeof(p_evidence) <> 'array' THEN
        RAISE EXCEPTION 'Evidence must be a JSON array.' USING ERRCODE = 'DC422';
    END IF;
    IF length(coalesce(p_summary, '') || coalesce(p_root_cause, '') || coalesce(p_evidence::text, '')) > 32000 THEN
        RAISE EXCEPTION 'AI analysis too large.' USING ERRCODE = 'DC422';
    END IF;

    INSERT INTO public.ai_analyses
        (incident_id, investigation_id, model_name, summary, root_cause, severity, confidence,
         evidence, recommended_action)
    VALUES
        (p_incident_id, p_investigation_id, left(p_model_name, 100), p_summary, p_root_cause, p_severity,
         p_confidence, coalesce(p_evidence, '[]'::jsonb), p_recommended_action)
    RETURNING id INTO v_id;

    IF p_investigation_id IS NOT NULL THEN
        UPDATE public.investigations
           SET status = 'completed', summary = p_summary, root_cause = p_root_cause,
               evidence = coalesce(p_evidence, '[]'::jsonb), ai_model = left(p_model_name, 100)
         WHERE id = p_investigation_id;
    END IF;

    PERFORM public.log_audit_event('AI_ANALYSIS_RECORDED', 'ai_analysis', v_id,
        jsonb_build_object('incident_id', p_incident_id, 'investigation_id', p_investigation_id,
                           'model_name', p_model_name, 'recommended_action', p_recommended_action));
    PERFORM public.write_incident_event(p_incident_id, 'investigation', 'AI analysis recorded',
        jsonb_build_object('ai_analysis_id', v_id, 'recommended_action', p_recommended_action));

    RETURN v_id;
END;
$$;

-- 4. BD-4: read context ---------------------------------------------------------
CREATE FUNCTION public.get_incident_context(p_incident_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_incident jsonb;
BEGIN
    PERFORM public.require_app_role(ARRAY['automation']);

    SELECT jsonb_build_object('id', i.id, 'title', i.title, 'description', i.description,
                              'severity', i.severity, 'status', i.status, 'service_name', i.service_name,
                              'environment', i.environment, 'detected_at', i.detected_at,
                              'resolved_at', i.resolved_at)
      INTO v_incident
      FROM public.incidents i WHERE i.id = p_incident_id;
    IF v_incident IS NULL THEN
        RAISE EXCEPTION 'Incident not found.' USING ERRCODE = 'DC404';
    END IF;

    RETURN jsonb_build_object(
        'incident', v_incident,
        'rca', (SELECT jsonb_build_object('id', a.id, 'summary', a.summary, 'root_cause', a.root_cause,
                                          'severity', a.severity, 'confidence', a.confidence,
                                          'evidence', a.evidence, 'recommended_action', a.recommended_action,
                                          'model_name', a.model_name, 'created_at', a.created_at)
                  FROM public.ai_analyses a WHERE a.incident_id = p_incident_id
                 ORDER BY a.created_at DESC LIMIT 1),
        'playbook_runs', coalesce((SELECT jsonb_agg(jsonb_build_object('id', r.id, 'status', r.status, 'requested_at', r.requested_at,
                                          'completed_at', r.completed_at) ORDER BY r.requested_at)
                  FROM public.playbook_runs r WHERE r.incident_id = p_incident_id), '[]'::jsonb),
        'recovery_checks', coalesce((SELECT jsonb_agg(jsonb_build_object('id', c.id, 'status', c.status,
                                          'check_type', c.check_type, 'playbook_run_id', c.playbook_run_id,
                                          'checked_at', c.checked_at) ORDER BY c.checked_at)
                  FROM public.recovery_checks c WHERE c.incident_id = p_incident_id), '[]'::jsonb),
        'timeline', coalesce((SELECT jsonb_agg(jsonb_build_object('time', e.occurred_at, 'type', e.event_type,
                                          'message', e.message) ORDER BY e.occurred_at)
                  FROM (SELECT * FROM public.incident_events ev WHERE ev.incident_id = p_incident_id
                         ORDER BY ev.occurred_at LIMIT 50) e), '[]'::jsonb));
END;
$$;

-- 5. BD-4: save postmortem --------------------------------------------------------
CREATE FUNCTION public.save_postmortem(
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

-- 6. Function privileges ------------------------------------------------------------
REVOKE ALL ON FUNCTION
    public.create_incident_from_alert(text, text, text, text, text, text, timestamptz),
    public.get_incident_context(uuid),
    public.save_postmortem(uuid, text, text, text, jsonb, text, jsonb, jsonb)
FROM PUBLIC, anon, authenticated;

-- require_app_role(['automation']) inside each function limits them to the
-- automation identity; EXECUTE is granted to authenticated as for the other
-- workflow functions (the automation identity signs in as authenticated).
GRANT EXECUTE ON FUNCTION
    public.create_incident_from_alert(text, text, text, text, text, text, timestamptz),
    public.get_incident_context(uuid),
    public.save_postmortem(uuid, text, text, text, jsonb, text, jsonb, jsonb)
TO authenticated;
