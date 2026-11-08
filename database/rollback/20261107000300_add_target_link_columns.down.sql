-- Rollback for 20261107000300_add_target_link_columns.sql
-- Safety: refuses to run if any link column already holds a value, so a
-- rollback can never silently discard data.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.ai_analyses WHERE investigation_id IS NOT NULL)
       OR EXISTS (SELECT 1 FROM public.recovery_checks
                  WHERE playbook_run_id IS NOT NULL OR automation_run_id IS NOT NULL OR checked_by IS NOT NULL)
       OR EXISTS (SELECT 1 FROM public.playbook_runs WHERE automation_run_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Rollback refused: link columns contain data. Export it first and get approval.';
    END IF;
END
$$;

ALTER TABLE public.playbook_runs DROP COLUMN IF EXISTS automation_run_id;
ALTER TABLE public.recovery_checks
    DROP COLUMN IF EXISTS checked_by,
    DROP COLUMN IF EXISTS automation_run_id,
    DROP COLUMN IF EXISTS playbook_run_id;
ALTER TABLE public.ai_analyses DROP COLUMN IF EXISTS investigation_id;
-- (Dropping a column also drops its foreign key and index.)
