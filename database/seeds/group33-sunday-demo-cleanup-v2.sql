-- =============================================================================
-- GROUP 33 | SUNDAY DEMO SEED v2 | GUARDED CLEANUP | REVIEW ONLY
-- Prepared: 2026-11-16
-- Companion: Group33_Sunday_Demo_Seed_v2_Approve_Reject_REVIEW_ONLY.sql
--
-- DO NOT RUN on any database without Vishwa + Vinuka's explicit approval.
-- Intended only for an explicitly approved, disposable demo environment.
--
-- IMPORTANT LIMITATION:
-- Migration 20261107000700_approval_workflow.sql enforces immutability:
--   A decided approval (approved, rejected, cancelled) CANNOT BE DELETED.
-- Therefore this cleanup works ONLY BEFORE either approval is decided.
-- If the phone demo has already approved/rejected a request, this script
-- RAISES AN ERROR and rolls back. Use an approved disposable DB snapshot
-- reset instead; NEVER disable the guard trigger or rewrite history.
--
-- Deletes ONLY fixed-ID rows created by companion seed v2, in FK order:
--   approvals -> playbook_runs -> ai_analyses -> incidents -> playbooks.
-- Never deletes/updates auth.users, profiles, or audit history.
-- Fails closed if other incident/run-linked data was created by the app,
-- to avoid silently cascading the removal of unrelated records.
-- =============================================================================

BEGIN;

DO $preflight$
DECLARE
  v_incident uuid := 'd3310000-0000-4000-8000-000000000001';
  v_analysis uuid := 'd3320000-0000-4000-8000-000000000001';
  v_run_approve uuid := 'd3340000-0000-4000-8000-000000000001';
  v_run_reject uuid := 'd3340000-0000-4000-8000-000000000002';
  v_approval_approve uuid := 'd3350000-0000-4000-8000-000000000001';
  v_approval_reject uuid := 'd3350000-0000-4000-8000-000000000002';
  v_playbook_approve uuid := 'd3330000-0000-4000-8000-000000000001';
  v_playbook_reject uuid := 'd3330000-0000-4000-8000-000000000002';
  v_requester uuid := '59b56aa4-1019-48f9-817c-30f3d10ca1dc';
BEGIN
  -- Schema must match reviewed migrations; do nothing otherwise.
  IF to_regclass('public.approvals') IS NULL OR
     to_regclass('public.playbook_runs') IS NULL OR
     to_regclass('public.ai_analyses') IS NULL OR
     to_regclass('public.incidents') IS NULL OR
     to_regclass('public.playbooks') IS NULL OR
     to_regclass('public.automation_runs') IS NULL OR
     to_regclass('public.incident_events') IS NULL THEN
    RAISE EXCEPTION 'Required schema tables not present; cleanup aborted.';
  END IF;

  -- Fixed IDs must still belong to the demo; refuse to delete collisions.
  IF EXISTS (
    SELECT 1 FROM public.incidents
    WHERE id = v_incident AND
      ROW(title, service_name, created_by, source, environment)
      IS DISTINCT FROM
      ROW('sample-app high error rate', 'sample-app', v_requester, 'manual', 'development')
  ) THEN
    RAISE EXCEPTION 'Demo incident ID belongs to a different/modified record.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.ai_analyses
    WHERE id = v_analysis AND ROW(incident_id, model_name)
      IS DISTINCT FROM ROW(v_incident, 'synthetic-demo')
  ) THEN
    RAISE EXCEPTION 'Demo analysis ID belongs to a different record.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.playbooks
    WHERE id = v_playbook_approve AND ROW(name, action_type)
      IS DISTINCT FROM ROW('Demo: sample-app restart (APPROVE)', 'restart')
  ) OR EXISTS (
    SELECT 1 FROM public.playbooks
    WHERE id = v_playbook_reject AND ROW(name, action_type)
      IS DISTINCT FROM ROW('Demo: sample-app restart (REJECT)', 'restart')
  ) THEN
    RAISE EXCEPTION 'A fixed demo playbook ID belongs to a different record.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.playbook_runs
    WHERE id = v_run_approve AND
      ROW(playbook_id, incident_id, requested_by, idempotency_key)
      IS DISTINCT FROM
      ROW(v_playbook_approve, v_incident, v_requester, 'group33-demo-approve-sample-app-restart')
  ) OR EXISTS (
    SELECT 1 FROM public.playbook_runs
    WHERE id = v_run_reject AND
      ROW(playbook_id, incident_id, requested_by, idempotency_key)
      IS DISTINCT FROM
      ROW(v_playbook_reject, v_incident, v_requester, 'group33-demo-reject-sample-app-restart')
  ) THEN
    RAISE EXCEPTION 'A fixed demo playbook run ID belongs to a different record.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.approvals
    WHERE id = v_approval_approve AND
      ROW(incident_id, playbook_run_id, requested_by)
      IS DISTINCT FROM ROW(v_incident, v_run_approve, v_requester)
  ) OR EXISTS (
    SELECT 1 FROM public.approvals
    WHERE id = v_approval_reject AND
      ROW(incident_id, playbook_run_id, requested_by)
      IS DISTINCT FROM ROW(v_incident, v_run_reject, v_requester)
  ) THEN
    RAISE EXCEPTION 'A fixed demo approval ID belongs to a different record.';
  END IF;

  -- No decided requests may be erased. This is enforced by a DB trigger too.
  IF EXISTS (
    SELECT 1 FROM public.approvals
    WHERE id IN (v_approval_approve, v_approval_reject)
      AND (status IS DISTINCT FROM 'pending' OR decided_at IS NOT NULL OR approver_id IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'A demo approval has been decided; cleanup forbidden. Restore an approved disposable DB snapshot instead.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.playbook_runs
    WHERE id IN (v_run_approve, v_run_reject)
      AND (status IS DISTINCT FROM 'pending_approval' OR approved_by IS NOT NULL OR approved_at IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'A demo playbook run has progressed; cleanup forbidden.';
  END IF;

  -- Reject unexpected linked records before deletion; otherwise a cascade
  -- could delete logs/notifications/data created by real system execution.
  IF EXISTS (
    SELECT 1 FROM public.approvals
    WHERE (incident_id = v_incident OR playbook_run_id IN (v_run_approve, v_run_reject))
      AND id NOT IN (v_approval_approve, v_approval_reject)
  ) OR EXISTS (
    SELECT 1 FROM public.playbook_runs
    WHERE (incident_id = v_incident OR playbook_id IN (v_playbook_approve, v_playbook_reject))
      AND id NOT IN (v_run_approve, v_run_reject)
  ) OR EXISTS (
    SELECT 1 FROM public.ai_analyses
    WHERE incident_id = v_incident AND id <> v_analysis
  ) OR EXISTS (SELECT 1 FROM public.automation_runs
                WHERE incident_id = v_incident
                   OR playbook_run_id IN (v_run_approve, v_run_reject))
     OR EXISTS (SELECT 1 FROM public.incident_events WHERE incident_id = v_incident)
     OR EXISTS (SELECT 1 FROM public.incident_logs WHERE incident_id = v_incident)
     OR EXISTS (SELECT 1 FROM public.investigations WHERE incident_id = v_incident)
     OR EXISTS (SELECT 1 FROM public.notifications WHERE incident_id = v_incident)
     OR EXISTS (SELECT 1 FROM public.postmortems WHERE incident_id = v_incident)
     OR EXISTS (SELECT 1 FROM public.recovery_checks
                WHERE incident_id = v_incident
                   OR playbook_run_id IN (v_run_approve, v_run_reject))
     OR EXISTS (SELECT 1 FROM public.remediation_executions
                WHERE incident_id = v_incident
                   OR playbook_id IN (v_playbook_approve, v_playbook_reject))
  THEN
    RAISE EXCEPTION 'Additional incident/run-linked records exist; refusing destructive cleanup. Review dependencies with Vinuka.';
  END IF;

  RAISE NOTICE 'Fixture and relationship checks passed. Removing only still-pending demo seed rows.';
END;
$preflight$;

-- Child-to-parent order; never disable triggers or cascade manually.
DELETE FROM public.approvals
 WHERE id IN ('d3350000-0000-4000-8000-000000000001'::uuid,
              'd3350000-0000-4000-8000-000000000002'::uuid)
   AND status = 'pending';

DELETE FROM public.playbook_runs
 WHERE id IN ('d3340000-0000-4000-8000-000000000001'::uuid,
              'd3340000-0000-4000-8000-000000000002'::uuid)
   AND status = 'pending_approval';

DELETE FROM public.ai_analyses
 WHERE id = 'd3320000-0000-4000-8000-000000000001'::uuid
   AND incident_id = 'd3310000-0000-4000-8000-000000000001'::uuid;

DELETE FROM public.incidents
 WHERE id = 'd3310000-0000-4000-8000-000000000001'::uuid
   AND title = 'sample-app high error rate';

DELETE FROM public.playbooks
 WHERE (id = 'd3330000-0000-4000-8000-000000000001'::uuid
        AND name = 'Demo: sample-app restart (APPROVE)')
    OR (id = 'd3330000-0000-4000-8000-000000000002'::uuid
        AND name = 'Demo: sample-app restart (REJECT)');

COMMIT;

-- Retained intentionally: the two already-provisioned Auth users, their
-- profiles, and audit records. No database table is truncated. Re-running
-- after a successful pending-only cleanup removes 0 rows. Do not execute this
-- after a real Approve/Reject demonstration: that history is immutable.
