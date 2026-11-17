-- Rollback for 20261118000200_remediation_dispatch_outbox.sql
-- Drops the claim function, the index and the two dispatch columns. The
-- columns only hold retry bookkeeping (no business data), so this rollback
-- does not refuse to run; runs still "approved" are not changed.

DROP FUNCTION IF EXISTS public.claim_runs_for_dispatch(integer, integer, integer, integer);
DROP INDEX IF EXISTS public.playbook_runs_approved_dispatch_idx;
ALTER TABLE public.playbook_runs DROP CONSTRAINT IF EXISTS playbook_runs_dispatch_attempts_check;
ALTER TABLE public.playbook_runs DROP COLUMN IF EXISTS last_dispatch_at;
ALTER TABLE public.playbook_runs DROP COLUMN IF EXISTS dispatch_attempts;
