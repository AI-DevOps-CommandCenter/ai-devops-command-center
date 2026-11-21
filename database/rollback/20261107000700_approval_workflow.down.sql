-- Rollback for 20261107000700_approval_workflow.sql
-- Safety: refuses to run when any row uses the new columns or the new
-- 'cancelled' approval status, because dropping them would lose data.
-- Note: the backend must be switched back to direct table writes in the same
-- release (the grants restored below).
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.approvals
               WHERE playbook_run_id IS NOT NULL OR decision_reason IS NOT NULL OR status = 'cancelled')
       OR EXISTS (SELECT 1 FROM public.playbook_runs
                  WHERE idempotency_key IS NOT NULL OR status_reason IS NOT NULL OR completed_by IS NOT NULL) THEN
        RAISE EXCEPTION 'Rollback refused: approvals/playbook_runs contain data in the new workflow columns. Export it first and get approval.';
    END IF;
END
$$;

-- Access back to the baseline
REVOKE SELECT ON TABLE public.ai_analyses, public.recovery_checks FROM authenticated;
DROP POLICY IF EXISTS "Read recovery checks of visible incidents" ON public.recovery_checks;
DROP POLICY IF EXISTS "Read AI analyses of visible incidents" ON public.ai_analyses;

DROP POLICY IF EXISTS "Users view own approvals or managers view all" ON public.approvals;
CREATE POLICY "Users view own approvals or admin" ON public.approvals
    FOR SELECT TO authenticated
    USING (((requested_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_admin() AS is_admin)));

GRANT INSERT, UPDATE ON TABLE public.approvals, public.playbook_runs, public.remediation_executions
    TO authenticated;

-- Functions
DROP FUNCTION IF EXISTS public.record_recovery_check(uuid, uuid, text, text, jsonb);
DROP FUNCTION IF EXISTS public.record_ai_analysis(uuid, uuid, text, text, text, text, numeric, jsonb, text);
DROP FUNCTION IF EXISTS public.complete_playbook_run(uuid, text, jsonb, text, text);
DROP FUNCTION IF EXISTS public.start_playbook_run(uuid, text, text);
DROP FUNCTION IF EXISTS public.cancel_playbook_run(uuid, text);
DROP FUNCTION IF EXISTS public.cancel_approval(uuid, text);
DROP FUNCTION IF EXISTS public.decide_approval(uuid, text, text);
DROP FUNCTION IF EXISTS public.request_playbook_run(uuid, uuid, text, jsonb);
DROP FUNCTION IF EXISTS public.notify_approvers(uuid, uuid, text, text);

DROP TRIGGER IF EXISTS approvals_no_truncate ON public.approvals;
DROP TRIGGER IF EXISTS approvals_immutable_decision ON public.approvals;
DROP FUNCTION IF EXISTS public.guard_approval_decision();

-- playbook_runs
DROP INDEX IF EXISTS public.idx_playbook_runs_completed_by;
DROP INDEX IF EXISTS public.playbook_runs_one_active_per_incident_playbook;
DROP INDEX IF EXISTS public.playbook_runs_idempotency_key_key;
ALTER TABLE public.playbook_runs
    DROP CONSTRAINT IF EXISTS playbook_runs_approver_not_requester,
    DROP CONSTRAINT IF EXISTS playbook_runs_status_reason_length,
    DROP CONSTRAINT IF EXISTS playbook_runs_idempotency_key_length,
    DROP CONSTRAINT IF EXISTS playbook_runs_completed_by_fkey,
    DROP COLUMN IF EXISTS completed_by,
    DROP COLUMN IF EXISTS status_reason,
    DROP COLUMN IF EXISTS idempotency_key;

-- approvals
ALTER TABLE public.approvals DROP CONSTRAINT approvals_status_check;
ALTER TABLE public.approvals ADD CONSTRAINT approvals_status_check
    CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])));
ALTER TABLE public.approvals
    DROP CONSTRAINT IF EXISTS approvals_decision_reason_length,
    DROP CONSTRAINT IF EXISTS approvals_approver_not_requester,
    DROP CONSTRAINT IF EXISTS approvals_playbook_run_id_key,
    DROP CONSTRAINT IF EXISTS approvals_playbook_run_id_fkey,
    DROP COLUMN IF EXISTS decision_reason,
    DROP COLUMN IF EXISTS playbook_run_id;
