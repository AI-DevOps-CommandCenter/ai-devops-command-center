-- Rollback for 20261107000100_add_missing_fk_indexes.sql (indexes only, no data).
DROP INDEX IF EXISTS public.idx_approvals_incident_id;
DROP INDEX IF EXISTS public.idx_approvals_requested_by;
DROP INDEX IF EXISTS public.idx_approvals_approver_id;
DROP INDEX IF EXISTS public.idx_audit_logs_actor_id;
DROP INDEX IF EXISTS public.idx_audit_logs_created_at;
DROP INDEX IF EXISTS public.idx_audit_logs_entity;
DROP INDEX IF EXISTS public.idx_incidents_created_by;
DROP INDEX IF EXISTS public.idx_integrations_created_by;
DROP INDEX IF EXISTS public.idx_remediation_executions_playbook_id;
DROP INDEX IF EXISTS public.idx_remediation_executions_triggered_by;
