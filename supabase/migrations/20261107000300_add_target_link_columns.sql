-- =============================================================================
-- Migration: nullable link columns to the new target tables
-- Status:    ADDITIVE. New NULL-able columns only; existing rows and values are
--            untouched (all new columns are NULL for existing rows).
-- Source:    database/MIGRATION_MAPPING.md §2.7 (ai_analyses), §2.11
--            (recovery_checks), §2.9 (playbook_runs.automation_run_id).
-- Rollback:  database/rollback/20261107000300_add_target_link_columns.down.sql
--
-- Deliberately NOT included (pending decisions):
--   approvals.playbook_run_id / playbook_runs.approval_id (U2, A3),
--   playbook_runs.legacy_source* (U1), new approval statuses (A3),
--   profiles role 'automation' (A5), actor_type columns (A9),
--   incidents.archived_at (A8-Q5), notifications.type/payload (A6),
--   ai_analyses severity 'info' (R11).
--
-- Delete behaviour: SET NULL, matching the existing optional references on
-- these tables, so existing cascades keep working unchanged.
-- Note: clients that already hold table-level UPDATE on playbook_runs
-- (managers, through RLS) can also write automation_run_id. That closes when
-- direct client writes on workflow tables are revoked (A2-Q3).
-- =============================================================================

ALTER TABLE public.ai_analyses
    ADD COLUMN investigation_id uuid,
    ADD CONSTRAINT ai_analyses_investigation_id_fkey FOREIGN KEY (investigation_id)
        REFERENCES public.investigations(id) ON DELETE SET NULL;

ALTER TABLE public.recovery_checks
    ADD COLUMN playbook_run_id uuid,
    ADD COLUMN automation_run_id uuid,
    ADD COLUMN checked_by uuid,
    ADD CONSTRAINT recovery_checks_playbook_run_id_fkey FOREIGN KEY (playbook_run_id)
        REFERENCES public.playbook_runs(id) ON DELETE SET NULL,
    ADD CONSTRAINT recovery_checks_automation_run_id_fkey FOREIGN KEY (automation_run_id)
        REFERENCES public.automation_runs(id) ON DELETE SET NULL,
    ADD CONSTRAINT recovery_checks_checked_by_fkey FOREIGN KEY (checked_by)
        REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.playbook_runs
    ADD COLUMN automation_run_id uuid,
    ADD CONSTRAINT playbook_runs_automation_run_id_fkey FOREIGN KEY (automation_run_id)
        REFERENCES public.automation_runs(id) ON DELETE SET NULL;

CREATE INDEX idx_ai_analyses_investigation_id
    ON public.ai_analyses USING btree (investigation_id);
CREATE INDEX idx_recovery_checks_playbook_run_id
    ON public.recovery_checks USING btree (playbook_run_id);
CREATE INDEX idx_recovery_checks_automation_run_id
    ON public.recovery_checks USING btree (automation_run_id);
CREATE INDEX idx_recovery_checks_checked_by
    ON public.recovery_checks USING btree (checked_by);
CREATE INDEX idx_playbook_runs_automation_run_id
    ON public.playbook_runs USING btree (automation_run_id);
