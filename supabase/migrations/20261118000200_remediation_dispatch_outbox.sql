-- =============================================================================
-- Migration: dispatch outbox for approved remediation runs (Day 3, BD-5 follow-up)
--
-- After an approval the backend sends the signed webhook to n8n workflow 06 at
-- once (in memory, 3 retries). If the backend restarts, or n8n is down for
-- longer than those retries, the run stayed "approved" and nothing sent it again.
--
-- "Approved runs are the outbox": every run in status 'approved' still has to
-- reach n8n. claim_runs_for_dispatch() hands such runs to the backend's outbox
-- worker, atomically (FOR UPDATE SKIP LOCKED), and records each attempt:
--   - only runs approved at least p_grace_seconds ago (the immediate dispatch
--     gets the first chance),
--   - at most once per p_retry_seconds per run,
--   - at most p_max_attempts times.
-- Runs that used up their attempts (still 'approved' one retry interval after
-- the last attempt, so n8n never started them) are flagged once, in the same
-- claim pass: playbook_runs.dispatch_failed_at is set, the incident timeline
-- gets an error event, the audit log gets PLAYBOOK_RUN_DISPATCH_FAILED, and
-- every operator and admin gets an in-app + push notification. Operators find
-- them in their inbox, on the incident timeline, and with
-- GET /api/playbook-runs?dispatch_failed=true; they cancel the run (existing
-- cancel_playbook_run) and request it again once n8n is back.
-- A second webhook for a run that n8n already started is harmless: n8n claims
-- every webhook nonce (KI-1) and start_playbook_run starts a run only once.
--
-- Automation-only (A5): the backend calls it with the automation identity.
-- Rollback: database/rollback/20261118000200_remediation_dispatch_outbox.down.sql
-- =============================================================================

ALTER TABLE public.playbook_runs
    ADD COLUMN IF NOT EXISTS dispatch_attempts integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_dispatch_at timestamptz,
    ADD COLUMN IF NOT EXISTS dispatch_failed_at timestamptz;

ALTER TABLE public.playbook_runs
    ADD CONSTRAINT playbook_runs_dispatch_attempts_check CHECK (dispatch_attempts >= 0);

CREATE INDEX IF NOT EXISTS playbook_runs_dispatch_failed_idx
    ON public.playbook_runs (dispatch_failed_at)
    WHERE dispatch_failed_at IS NOT NULL;

COMMENT ON COLUMN public.playbook_runs.dispatch_attempts IS
    'Webhook dispatch attempts by the backend outbox worker (claim_runs_for_dispatch).';
COMMENT ON COLUMN public.playbook_runs.last_dispatch_at IS
    'When the outbox worker last claimed this approved run for a webhook dispatch.';
COMMENT ON COLUMN public.playbook_runs.dispatch_failed_at IS
    'Set once when the run used up its dispatch attempts without n8n starting it; operators and admins are notified.';

-- Finds the runs still waiting for n8n.
CREATE INDEX IF NOT EXISTS playbook_runs_approved_dispatch_idx
    ON public.playbook_runs (approved_at)
    WHERE status = 'approved';

CREATE FUNCTION public.claim_runs_for_dispatch(
    p_limit integer DEFAULT 10,
    p_grace_seconds integer DEFAULT 30,
    p_retry_seconds integer DEFAULT 30,
    p_max_attempts integer DEFAULT 10
) RETURNS TABLE (
    run_id uuid,
    incident_id uuid,
    action_type text,
    request_payload jsonb,
    dispatch_attempts integer
)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_run record;
BEGIN
    PERFORM public.require_app_role(ARRAY['automation']);

    IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
       OR p_grace_seconds IS NULL OR p_grace_seconds NOT BETWEEN 0 AND 3600
       OR p_retry_seconds IS NULL OR p_retry_seconds NOT BETWEEN 5 AND 3600
       OR p_max_attempts IS NULL OR p_max_attempts NOT BETWEEN 1 AND 100 THEN
        RAISE EXCEPTION 'Invalid dispatch claim parameters.' USING ERRCODE = 'DC422';
    END IF;

    -- Runs that used up their attempts: flag once and tell the operators.
    FOR v_run IN
        SELECT r.id, r.incident_id, r.dispatch_attempts, p.name AS playbook_name
        FROM public.playbook_runs r
        JOIN public.playbooks p ON p.id = r.playbook_id
        WHERE r.status = 'approved'
          AND r.dispatch_failed_at IS NULL
          AND r.dispatch_attempts >= p_max_attempts
          AND r.last_dispatch_at <= now() - make_interval(secs => p_retry_seconds)
        ORDER BY r.last_dispatch_at
        LIMIT p_limit
        FOR UPDATE OF r SKIP LOCKED
    LOOP
        UPDATE public.playbook_runs SET dispatch_failed_at = now() WHERE id = v_run.id;
        PERFORM public.log_audit_event('PLAYBOOK_RUN_DISPATCH_FAILED', 'playbook_run', v_run.id,
            jsonb_build_object('incident_id', v_run.incident_id, 'dispatch_attempts', v_run.dispatch_attempts));
        PERFORM public.write_incident_event(v_run.incident_id, 'remediation',
            format('Approved remediation "%s" could not reach automation after %s attempts. Cancel it and request it again.',
                   v_run.playbook_name, v_run.dispatch_attempts),
            jsonb_build_object('playbook_run_id', v_run.id, 'dispatch_attempts', v_run.dispatch_attempts),
            'error');
        PERFORM public.notify_approvers(NULL, v_run.incident_id, 'Remediation not sent',
            format('"%s" was approved but could not reach automation after %s attempts. Open the incident to cancel and retry.',
                   v_run.playbook_name, v_run.dispatch_attempts));
    END LOOP;

    RETURN QUERY
    WITH due AS (
        SELECT r.id
        FROM public.playbook_runs r
        WHERE r.status = 'approved'
          AND coalesce(r.approved_at, r.requested_at) <= now() - make_interval(secs => p_grace_seconds)
          AND (r.last_dispatch_at IS NULL OR r.last_dispatch_at <= now() - make_interval(secs => p_retry_seconds))
          AND r.dispatch_attempts < p_max_attempts
        ORDER BY coalesce(r.approved_at, r.requested_at)
        LIMIT p_limit
        FOR UPDATE OF r SKIP LOCKED
    ), claimed AS (
        UPDATE public.playbook_runs r
        SET dispatch_attempts = r.dispatch_attempts + 1,
            last_dispatch_at = now()
        FROM due
        WHERE r.id = due.id
        RETURNING r.id, r.incident_id, r.playbook_id, r.request_payload, r.dispatch_attempts
    )
    SELECT c.id, c.incident_id, p.action_type, c.request_payload, c.dispatch_attempts
    FROM claimed c
    JOIN public.playbooks p ON p.id = c.playbook_id;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_runs_for_dispatch(integer, integer, integer, integer)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_runs_for_dispatch(integer, integer, integer, integer) TO authenticated;
