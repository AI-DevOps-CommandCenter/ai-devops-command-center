-- =============================================================================
-- Migration: single approval workflow, remediation lifecycle, boundary
-- Decisions (approved 2026-11-07):
--   A2  Normal user-specific reads with JWT + RLS. Critical workflow
--       operations only through narrow SECURITY DEFINER functions (called by
--       the backend). Direct client writes on approvals, playbook_runs,
--       remediation_executions are revoked (A2-Q3). No service_role.
--   A3  One authoritative approval system: every approval is linked 1:1 to a
--       playbook_run. Decisions are immutable; requester and approver are
--       different people; idempotent requests; no duplicate execution.
--       A3-Q1: approvers = admin and operator, never for their own request.
--       A3-Q3: n8n completes runs; admins/operators may complete manually
--              with a reason (audited).
--       A3-Q4: no expiry/timeouts for now.
--   A4  Human approval for EVERY remediation action (restart, rollback,
--       scale, circuit_breaker), regardless of playbooks.requires_approval.
--   A5  start/complete for the automation identity (via the backend).
--   A7  Every function writes its audit entry in the same transaction.
-- Rollback: database/rollback/20261107000700_approval_workflow.down.sql
--
-- Existing rows are not modified. Legacy rows (an approval without a run, a
-- run without an approval, the legacy remediation execution) stay as they
-- are; see database/DATABASE_TEAM_HANDOVER.md §7.
-- =============================================================================

-- 1. Approvals: link to the run, cancellation, separation of duties ----------------
ALTER TABLE public.approvals
    ADD COLUMN playbook_run_id uuid,
    ADD COLUMN decision_reason text,
    ADD CONSTRAINT approvals_playbook_run_id_fkey FOREIGN KEY (playbook_run_id)
        REFERENCES public.playbook_runs(id),
    -- 1:1 with the run (NULL only for legacy approvals created before this migration)
    ADD CONSTRAINT approvals_playbook_run_id_key UNIQUE (playbook_run_id),
    ADD CONSTRAINT approvals_approver_not_requester
        CHECK (approver_id IS NULL OR requested_by IS NULL OR approver_id <> requested_by),
    ADD CONSTRAINT approvals_decision_reason_length
        CHECK (decision_reason IS NULL OR length(decision_reason) <= 1000);

ALTER TABLE public.approvals DROP CONSTRAINT approvals_status_check;
ALTER TABLE public.approvals ADD CONSTRAINT approvals_status_check
    CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'cancelled'::text]));

COMMENT ON COLUMN public.approvals.playbook_run_id IS
    'The run this approval decides (A3, 1:1). NULL only for legacy approvals.';

-- 2. Playbook runs: idempotency, reasons, duplicate prevention ----------------------
ALTER TABLE public.playbook_runs
    ADD COLUMN idempotency_key text,
    ADD COLUMN status_reason text,
    ADD COLUMN completed_by uuid,
    ADD CONSTRAINT playbook_runs_completed_by_fkey FOREIGN KEY (completed_by)
        REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD CONSTRAINT playbook_runs_idempotency_key_length
        CHECK (idempotency_key IS NULL OR length(idempotency_key) BETWEEN 8 AND 200),
    ADD CONSTRAINT playbook_runs_status_reason_length
        CHECK (status_reason IS NULL OR length(status_reason) <= 1000),
    ADD CONSTRAINT playbook_runs_approver_not_requester
        CHECK (approved_by IS NULL OR requested_by IS NULL OR approved_by <> requested_by);

-- Same requester + same key = same request.
CREATE UNIQUE INDEX playbook_runs_idempotency_key_key
    ON public.playbook_runs USING btree (requested_by, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- At most one active run per incident and playbook.
CREATE UNIQUE INDEX playbook_runs_one_active_per_incident_playbook
    ON public.playbook_runs USING btree (incident_id, playbook_id)
    WHERE status = ANY (ARRAY['pending_approval'::text, 'approved'::text, 'running'::text]);

CREATE INDEX idx_playbook_runs_completed_by ON public.playbook_runs USING btree (completed_by);

-- 3. Immutable approval decisions (all roles) ----------------------------------------
-- A decided or cancelled approval cannot be changed or deleted. The only change
-- allowed is the ON DELETE SET NULL of a deleted profile on the actor columns
-- (who acted remains in audit_logs).
CREATE FUNCTION public.guard_approval_decision() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
BEGIN
    IF TG_OP = 'TRUNCATE' THEN
        RAISE EXCEPTION 'approvals cannot be truncated.' USING ERRCODE = 'DC403';
    END IF;

    IF TG_OP = 'DELETE' THEN
        IF OLD.status <> 'pending' THEN
            RAISE EXCEPTION 'A decided approval cannot be deleted.' USING ERRCODE = 'DC409';
        END IF;
        RETURN OLD;
    END IF;

    -- Identity of the request never changes.
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.incident_id IS DISTINCT FROM OLD.incident_id
       OR NEW.requested_at IS DISTINCT FROM OLD.requested_at
       OR (OLD.playbook_run_id IS NOT NULL AND NEW.playbook_run_id IS DISTINCT FROM OLD.playbook_run_id)
       OR (NEW.requested_by IS DISTINCT FROM OLD.requested_by AND NEW.requested_by IS NOT NULL) THEN
        RAISE EXCEPTION 'The approval request itself cannot be changed.' USING ERRCODE = 'DC409';
    END IF;

    IF OLD.status <> 'pending' THEN
        IF (NEW.status, NEW.comments, NEW.decided_at, NEW.decision_reason, NEW.playbook_run_id)
               IS NOT DISTINCT FROM
           (OLD.status, OLD.comments, OLD.decided_at, OLD.decision_reason, OLD.playbook_run_id)
           AND (NEW.approver_id IS NOT DISTINCT FROM OLD.approver_id OR NEW.approver_id IS NULL) THEN
            RETURN NEW;  -- FK SET NULL of a deleted profile
        END IF;
        RAISE EXCEPTION 'A decided approval cannot be changed.' USING ERRCODE = 'DC409';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER approvals_immutable_decision
    BEFORE UPDATE OR DELETE ON public.approvals
    FOR EACH ROW EXECUTE FUNCTION public.guard_approval_decision();
CREATE TRIGGER approvals_no_truncate
    BEFORE TRUNCATE ON public.approvals
    FOR EACH STATEMENT EXECUTE FUNCTION public.guard_approval_decision();

-- 4. Internal helper -------------------------------------------------------------------
CREATE FUNCTION public.notify_approvers(p_requester uuid, p_incident_id uuid, p_title text, p_message text)
RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_id uuid;
BEGIN
    FOR v_id IN
        SELECT id FROM public.profiles
        WHERE role IN ('admin', 'operator') AND id IS DISTINCT FROM p_requester
    LOOP
        PERFORM public.write_notification(v_id, p_incident_id, p_title, p_message, ARRAY['in_app', 'push']);
    END LOOP;
END;
$$;

-- 5. Workflow functions ----------------------------------------------------------------

-- Any signed-in human may request a run for an incident they can see.
-- Always creates a pending approval (A4). Same idempotency key => same run.
CREATE FUNCTION public.request_playbook_run(
    p_incident_id uuid,
    p_playbook_id uuid,
    p_idempotency_key text DEFAULT NULL,
    p_request_payload jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['user', 'operator', 'admin']);
    v_role text := public.current_app_role();
    v_payload jsonb := coalesce(p_request_payload, '{}'::jsonb);
    v_incident record;
    v_playbook record;
    v_existing record;
    v_run_id uuid;
    v_approval_id uuid;
    v_constraint text;
BEGIN
    IF p_incident_id IS NULL OR p_playbook_id IS NULL THEN
        RAISE EXCEPTION 'Incident and playbook are required.' USING ERRCODE = 'DC422';
    END IF;
    IF p_idempotency_key IS NOT NULL AND length(p_idempotency_key) NOT BETWEEN 8 AND 200 THEN
        RAISE EXCEPTION 'Idempotency key must be 8 to 200 characters.' USING ERRCODE = 'DC422';
    END IF;
    IF jsonb_typeof(v_payload) <> 'object' OR length(v_payload::text) > 16000 THEN
        RAISE EXCEPTION 'Request payload must be a JSON object (max 16 kB).' USING ERRCODE = 'DC422';
    END IF;

    -- Idempotent retry: return the run created by the first call.
    IF p_idempotency_key IS NOT NULL THEN
        SELECT r.id, r.incident_id, r.playbook_id, r.status, a.id AS approval_id
        INTO v_existing
        FROM public.playbook_runs r
        LEFT JOIN public.approvals a ON a.playbook_run_id = r.id
        WHERE r.requested_by = v_uid AND r.idempotency_key = p_idempotency_key;

        IF FOUND THEN
            IF v_existing.incident_id <> p_incident_id OR v_existing.playbook_id <> p_playbook_id THEN
                RAISE EXCEPTION 'This idempotency key was already used for a different request.'
                    USING ERRCODE = 'DC409';
            END IF;
            RETURN jsonb_build_object('run_id', v_existing.id, 'status', v_existing.status,
                                      'approval_id', v_existing.approval_id, 'created', false);
        END IF;
    END IF;

    SELECT id, created_by, status INTO v_incident FROM public.incidents WHERE id = p_incident_id;
    IF NOT FOUND OR (v_role = 'user' AND v_incident.created_by IS DISTINCT FROM v_uid) THEN
        RAISE EXCEPTION 'Incident not found.' USING ERRCODE = 'DC404';
    END IF;
    IF v_incident.status IN ('resolved', 'closed') THEN
        RAISE EXCEPTION 'The incident is already resolved or closed.' USING ERRCODE = 'DC409';
    END IF;

    SELECT id, name, action_type, enabled INTO v_playbook FROM public.playbooks WHERE id = p_playbook_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Playbook not found.' USING ERRCODE = 'DC404';
    END IF;
    IF NOT v_playbook.enabled THEN
        RAISE EXCEPTION 'This playbook is disabled.' USING ERRCODE = 'DC409';
    END IF;

    BEGIN
        INSERT INTO public.playbook_runs
            (playbook_id, incident_id, requested_by, status, approval_required, request_payload, idempotency_key)
        VALUES
            (p_playbook_id, p_incident_id, v_uid, 'pending_approval', true, v_payload, p_idempotency_key)
        RETURNING id INTO v_run_id;
    EXCEPTION WHEN unique_violation THEN
        GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
        IF v_constraint = 'playbook_runs_one_active_per_incident_playbook' THEN
            RAISE EXCEPTION 'An active run already exists for this incident and playbook.'
                USING ERRCODE = 'DC409';
        END IF;
        RAISE EXCEPTION 'This idempotency key is already in use.' USING ERRCODE = 'DC409';
    END;

    INSERT INTO public.approvals (incident_id, requested_by, status, playbook_run_id)
    VALUES (p_incident_id, v_uid, 'pending', v_run_id)
    RETURNING id INTO v_approval_id;

    PERFORM public.log_audit_event('PLAYBOOK_RUN_REQUESTED', 'playbook_run', v_run_id,
        jsonb_build_object('incident_id', p_incident_id, 'playbook_id', p_playbook_id,
                           'action_type', v_playbook.action_type, 'approval_id', v_approval_id));
    PERFORM public.write_incident_event(p_incident_id, 'approval',
        format('Approval requested: %s', v_playbook.name),
        jsonb_build_object('playbook_run_id', v_run_id, 'approval_id', v_approval_id,
                           'action_type', v_playbook.action_type));
    PERFORM public.notify_approvers(v_uid, p_incident_id, 'Approval needed',
        format('%s was requested and needs approval.', v_playbook.name));

    RETURN jsonb_build_object('run_id', v_run_id, 'status', 'pending_approval',
                              'approval_id', v_approval_id, 'created', true);
END;
$$;

-- Admins and operators decide; never their own request (A3-Q1).
CREATE FUNCTION public.decide_approval(p_approval_id uuid, p_decision text, p_reason text DEFAULT NULL)
RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['operator', 'admin']);
    v_approval public.approvals%ROWTYPE;
    v_run public.playbook_runs%ROWTYPE;
BEGIN
    IF p_decision IS NULL OR p_decision NOT IN ('approved', 'rejected') THEN
        RAISE EXCEPTION 'Decision must be approved or rejected.' USING ERRCODE = 'DC422';
    END IF;
    IF p_reason IS NOT NULL AND length(p_reason) > 1000 THEN
        RAISE EXCEPTION 'Reason too long (max 1000).' USING ERRCODE = 'DC422';
    END IF;

    SELECT * INTO v_approval FROM public.approvals WHERE id = p_approval_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Approval not found.' USING ERRCODE = 'DC404';
    END IF;
    IF v_approval.requested_by = v_uid THEN
        RAISE EXCEPTION 'You cannot decide your own request.' USING ERRCODE = 'DC403';
    END IF;
    IF v_approval.status <> 'pending' THEN
        RAISE EXCEPTION 'This approval is already %.', v_approval.status USING ERRCODE = 'DC409';
    END IF;

    IF v_approval.playbook_run_id IS NOT NULL THEN
        SELECT * INTO v_run FROM public.playbook_runs WHERE id = v_approval.playbook_run_id FOR UPDATE;
        IF v_run.requested_by = v_uid THEN
            RAISE EXCEPTION 'You cannot decide your own request.' USING ERRCODE = 'DC403';
        END IF;
        IF v_run.status <> 'pending_approval' THEN
            RAISE EXCEPTION 'The playbook run is no longer waiting for approval.' USING ERRCODE = 'DC409';
        END IF;

        UPDATE public.playbook_runs
        SET status = p_decision,
            approved_by = CASE WHEN p_decision = 'approved' THEN v_uid END,
            approved_at = CASE WHEN p_decision = 'approved' THEN now() END,
            status_reason = p_reason
        WHERE id = v_run.id;
    END IF;

    UPDATE public.approvals
    SET status = p_decision, approver_id = v_uid, decided_at = now(), decision_reason = p_reason
    WHERE id = p_approval_id;

    PERFORM public.log_audit_event(
        CASE WHEN p_decision = 'approved' THEN 'APPROVAL_APPROVED' ELSE 'APPROVAL_REJECTED' END,
        'approval', p_approval_id,
        jsonb_build_object('incident_id', v_approval.incident_id, 'playbook_run_id', v_approval.playbook_run_id,
                           'requested_by', v_approval.requested_by, 'reason', p_reason));
    PERFORM public.write_incident_event(v_approval.incident_id, 'approval',
        format('Approval %s', p_decision),
        jsonb_build_object('approval_id', p_approval_id, 'playbook_run_id', v_approval.playbook_run_id));
    IF v_approval.requested_by IS NOT NULL THEN
        PERFORM public.write_notification(v_approval.requested_by, v_approval.incident_id,
            format('Request %s', p_decision), format('Your remediation request was %s.', p_decision),
            ARRAY['in_app', 'push']);
    END IF;

    RETURN jsonb_build_object('approval_id', p_approval_id, 'status', p_decision,
                              'playbook_run_id', v_approval.playbook_run_id,
                              'run_status', CASE WHEN v_approval.playbook_run_id IS NOT NULL THEN p_decision END);
END;
$$;

-- The requester withdraws a pending request.
CREATE FUNCTION public.cancel_approval(p_approval_id uuid, p_reason text DEFAULT NULL) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['user', 'operator', 'admin']);
    v_approval public.approvals%ROWTYPE;
BEGIN
    IF p_reason IS NOT NULL AND length(p_reason) > 1000 THEN
        RAISE EXCEPTION 'Reason too long (max 1000).' USING ERRCODE = 'DC422';
    END IF;

    SELECT * INTO v_approval FROM public.approvals WHERE id = p_approval_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Approval not found.' USING ERRCODE = 'DC404';
    END IF;
    IF v_approval.requested_by IS DISTINCT FROM v_uid THEN
        RAISE EXCEPTION 'Only the requester can cancel this request.' USING ERRCODE = 'DC403';
    END IF;
    IF v_approval.status <> 'pending' THEN
        RAISE EXCEPTION 'This approval is already %.', v_approval.status USING ERRCODE = 'DC409';
    END IF;

    UPDATE public.approvals
    SET status = 'cancelled', decided_at = now(), decision_reason = p_reason
    WHERE id = p_approval_id;

    UPDATE public.playbook_runs
    SET status = 'cancelled', status_reason = p_reason
    WHERE id = v_approval.playbook_run_id AND status = 'pending_approval';

    PERFORM public.log_audit_event('APPROVAL_CANCELLED', 'approval', p_approval_id,
        jsonb_build_object('incident_id', v_approval.incident_id,
                           'playbook_run_id', v_approval.playbook_run_id, 'reason', p_reason));
    PERFORM public.write_incident_event(v_approval.incident_id, 'approval', 'Approval request cancelled',
        jsonb_build_object('approval_id', p_approval_id, 'playbook_run_id', v_approval.playbook_run_id));

    RETURN jsonb_build_object('approval_id', p_approval_id, 'status', 'cancelled',
                              'playbook_run_id', v_approval.playbook_run_id);
END;
$$;

-- Pending: the requester or a manager. Approved/running: managers, with a reason.
CREATE FUNCTION public.cancel_playbook_run(p_run_id uuid, p_reason text DEFAULT NULL) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['user', 'operator', 'admin']);
    v_role text := public.current_app_role();
    v_run public.playbook_runs%ROWTYPE;
BEGIN
    IF p_reason IS NOT NULL AND length(p_reason) > 1000 THEN
        RAISE EXCEPTION 'Reason too long (max 1000).' USING ERRCODE = 'DC422';
    END IF;

    SELECT * INTO v_run FROM public.playbook_runs WHERE id = p_run_id FOR UPDATE;
    IF NOT FOUND OR (v_role = 'user' AND v_run.requested_by IS DISTINCT FROM v_uid) THEN
        RAISE EXCEPTION 'Playbook run not found.' USING ERRCODE = 'DC404';
    END IF;

    IF v_run.status IN ('approved', 'running') THEN
        IF v_role NOT IN ('operator', 'admin') THEN
            RAISE EXCEPTION 'Only admins and operators can cancel an approved or running run.'
                USING ERRCODE = 'DC403';
        END IF;
        IF p_reason IS NULL OR length(btrim(p_reason)) < 5 THEN
            RAISE EXCEPTION 'A reason is required to cancel an approved or running run.' USING ERRCODE = 'DC422';
        END IF;
    ELSIF v_run.status <> 'pending_approval' THEN
        RAISE EXCEPTION 'The run is already %.', v_run.status USING ERRCODE = 'DC409';
    END IF;

    UPDATE public.playbook_runs
    SET status = 'cancelled', status_reason = p_reason,
        completed_at = CASE WHEN v_run.status = 'running' THEN now() END
    WHERE id = p_run_id;

    UPDATE public.approvals
    SET status = 'cancelled', decided_at = now(), decision_reason = p_reason
    WHERE playbook_run_id = p_run_id AND status = 'pending';

    UPDATE public.automation_runs
    SET status = 'cancelled', completed_at = now()
    WHERE id = v_run.automation_run_id AND status IN ('queued', 'running');

    PERFORM public.log_audit_event('PLAYBOOK_RUN_CANCELLED', 'playbook_run', p_run_id,
        jsonb_build_object('incident_id', v_run.incident_id, 'previous_status', v_run.status, 'reason', p_reason));
    PERFORM public.write_incident_event(v_run.incident_id, 'remediation', 'Remediation cancelled',
        jsonb_build_object('playbook_run_id', p_run_id, 'previous_status', v_run.status));

    RETURN jsonb_build_object('run_id', p_run_id, 'status', 'cancelled');
END;
$$;

-- Automation only. Requires an approved run with an approved approval.
-- A second start of the same run, or a reused n8n execution id, is rejected.
CREATE FUNCTION public.start_playbook_run(
    p_run_id uuid,
    p_n8n_execution_id text,
    p_workflow_name text DEFAULT 'remediation'
) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['automation']);
    v_run public.playbook_runs%ROWTYPE;
    v_playbook record;
    v_automation_run_id uuid;
BEGIN
    IF p_n8n_execution_id IS NULL OR length(p_n8n_execution_id) NOT BETWEEN 1 AND 200
       OR p_workflow_name IS NULL OR length(p_workflow_name) NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'n8n execution id and workflow name are required.' USING ERRCODE = 'DC422';
    END IF;

    SELECT * INTO v_run FROM public.playbook_runs WHERE id = p_run_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Playbook run not found.' USING ERRCODE = 'DC404';
    END IF;
    IF v_run.status <> 'approved' THEN
        RAISE EXCEPTION 'The run is %, not approved.', v_run.status USING ERRCODE = 'DC409';
    END IF;

    SELECT name, action_type, enabled INTO v_playbook FROM public.playbooks WHERE id = v_run.playbook_id;
    IF NOT v_playbook.enabled THEN
        RAISE EXCEPTION 'This playbook is disabled.' USING ERRCODE = 'DC409';
    END IF;

    -- A4: every run needs an approved human approval.
    IF NOT EXISTS (SELECT 1 FROM public.approvals
                   WHERE playbook_run_id = p_run_id AND status = 'approved') THEN
        RAISE EXCEPTION 'The run has no approved approval.' USING ERRCODE = 'DC409';
    END IF;

    -- Duplicate n8n execution id -> 23505 (automation_runs_n8n_execution_id_key).
    INSERT INTO public.automation_runs
        (workflow_name, n8n_execution_id, trigger_type, incident_id, playbook_run_id, status, input, started_at)
    VALUES
        (p_workflow_name, p_n8n_execution_id, 'playbook_run', v_run.incident_id, p_run_id, 'running',
         v_run.request_payload, now())
    RETURNING id INTO v_automation_run_id;

    UPDATE public.playbook_runs
    SET status = 'running', started_at = now(), automation_run_id = v_automation_run_id
    WHERE id = p_run_id;

    PERFORM public.log_audit_event('PLAYBOOK_RUN_STARTED', 'playbook_run', p_run_id,
        jsonb_build_object('incident_id', v_run.incident_id, 'n8n_execution_id', p_n8n_execution_id,
                           'automation_run_id', v_automation_run_id));
    PERFORM public.write_incident_event(v_run.incident_id, 'remediation',
        format('Remediation started: %s', v_playbook.name),
        jsonb_build_object('playbook_run_id', p_run_id, 'automation_run_id', v_automation_run_id));

    RETURN jsonb_build_object('run_id', p_run_id, 'status', 'running',
                              'automation_run_id', v_automation_run_id, 'incident_id', v_run.incident_id,
                              'action_type', v_playbook.action_type, 'request_payload', v_run.request_payload);
END;
$$;

-- Automation reports the result with its execution id; admins/operators may
-- complete manually with a reason (A3-Q3).
CREATE FUNCTION public.complete_playbook_run(
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

    RETURN jsonb_build_object('run_id', p_run_id, 'status', p_status, 'manual', v_manual);
END;
$$;

-- Automation only (A5). AI output is never accepted from humans (A9-Q2 open).
CREATE FUNCTION public.record_ai_analysis(
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

    -- severity, confidence and recommended_action are validated by the table's CHECKs.
    INSERT INTO public.ai_analyses
        (incident_id, investigation_id, model_name, summary, root_cause, severity, confidence,
         evidence, recommended_action)
    VALUES
        (p_incident_id, p_investigation_id, left(p_model_name, 100), p_summary, p_root_cause, p_severity,
         p_confidence, coalesce(p_evidence, '[]'::jsonb), p_recommended_action)
    RETURNING id INTO v_id;

    PERFORM public.log_audit_event('AI_ANALYSIS_RECORDED', 'ai_analysis', v_id,
        jsonb_build_object('incident_id', p_incident_id, 'investigation_id', p_investigation_id,
                           'model_name', p_model_name, 'recommended_action', p_recommended_action));
    PERFORM public.write_incident_event(p_incident_id, 'investigation', 'AI analysis recorded',
        jsonb_build_object('ai_analysis_id', v_id, 'recommended_action', p_recommended_action));

    RETURN v_id;
END;
$$;

-- Automation or managers record post-remediation health checks.
CREATE FUNCTION public.record_recovery_check(
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

    RETURN v_id;
END;
$$;

-- 6. Boundary (A2) -----------------------------------------------------------------------
-- No direct client writes on the workflow tables: only the functions above.
REVOKE INSERT, UPDATE ON TABLE public.approvals              FROM authenticated;
REVOKE INSERT, UPDATE ON TABLE public.playbook_runs          FROM authenticated;
REVOKE INSERT, UPDATE ON TABLE public.remediation_executions FROM authenticated;

-- Approvers (admin and operator, A3-Q1) must be able to see approval requests.
DROP POLICY "Users view own approvals or admin" ON public.approvals;
CREATE POLICY "Users view own approvals or managers view all" ON public.approvals
    FOR SELECT TO authenticated
    USING (requested_by = (SELECT auth.uid()) OR (SELECT public.is_incident_manager()));

-- Read access to AI results and recovery checks follows incident visibility.
GRANT SELECT ON TABLE public.ai_analyses, public.recovery_checks TO authenticated;

CREATE POLICY "Read AI analyses of visible incidents" ON public.ai_analyses
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.incidents i
        WHERE i.id = ai_analyses.incident_id
          AND (i.created_by = (SELECT auth.uid()) OR (SELECT public.is_incident_manager()))));

CREATE POLICY "Read recovery checks of visible incidents" ON public.recovery_checks
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.incidents i
        WHERE i.id = recovery_checks.incident_id
          AND (i.created_by = (SELECT auth.uid()) OR (SELECT public.is_incident_manager()))));

-- 7. Function privileges --------------------------------------------------------------------
REVOKE ALL ON FUNCTION
    public.guard_approval_decision(),
    public.notify_approvers(uuid, uuid, text, text),
    public.request_playbook_run(uuid, uuid, text, jsonb),
    public.decide_approval(uuid, text, text),
    public.cancel_approval(uuid, text),
    public.cancel_playbook_run(uuid, text),
    public.start_playbook_run(uuid, text, text),
    public.complete_playbook_run(uuid, text, jsonb, text, text),
    public.record_ai_analysis(uuid, uuid, text, text, text, text, numeric, jsonb, text),
    public.record_recovery_check(uuid, uuid, text, text, jsonb)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
    public.request_playbook_run(uuid, uuid, text, jsonb),
    public.decide_approval(uuid, text, text),
    public.cancel_approval(uuid, text),
    public.cancel_playbook_run(uuid, text),
    public.start_playbook_run(uuid, text, text),
    public.complete_playbook_run(uuid, text, jsonb, text, text),
    public.record_ai_analysis(uuid, uuid, text, text, text, text, numeric, jsonb, text),
    public.record_recovery_check(uuid, uuid, text, text, jsonb)
TO authenticated;
