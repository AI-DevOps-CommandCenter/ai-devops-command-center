-- =============================================================================
-- Migration: indexes for unindexed foreign-key and filter columns
-- Status:    ADDITIVE, performance only. No data change, no behaviour change.
-- Source:    roadmap §2.1 "Missing indexes" (verified against the baseline).
-- Rollback:  database/rollback/20261107000100_add_missing_fk_indexes.down.sql
-- Note:      the tables are small; plain CREATE INDEX (not CONCURRENTLY) is used
--            so the migration can run inside a transaction.
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_approvals_incident_id
    ON public.approvals USING btree (incident_id);
CREATE INDEX IF NOT EXISTS idx_approvals_requested_by
    ON public.approvals USING btree (requested_by);
CREATE INDEX IF NOT EXISTS idx_approvals_approver_id
    ON public.approvals USING btree (approver_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id
    ON public.audit_logs USING btree (actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at
    ON public.audit_logs USING btree (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity
    ON public.audit_logs USING btree (entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_incidents_created_by
    ON public.incidents USING btree (created_by);

CREATE INDEX IF NOT EXISTS idx_integrations_created_by
    ON public.integrations USING btree (created_by);

CREATE INDEX IF NOT EXISTS idx_remediation_executions_playbook_id
    ON public.remediation_executions USING btree (playbook_id);
CREATE INDEX IF NOT EXISTS idx_remediation_executions_triggered_by
    ON public.remediation_executions USING btree (triggered_by);
