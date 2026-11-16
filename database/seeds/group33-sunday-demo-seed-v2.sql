-- =============================================================================
-- GROUP 33 | SUNDAY DEMO SEED v2 | APPROVE + REJECT | REVIEW ONLY
-- Prepared: 2026-11-15
-- DO NOT EXECUTE on shared/production Supabase before Vishwa + Vinuka review.
-- Intended environment: the specifically approved demo Supabase database which
-- already contains the two real, separately created DEMO Auth users below.
-- This file DOES NOT create/update auth.users or public.profiles.
--
-- Schema references reviewed:
--   supabase/migrations/20261107000000_baseline_live_public_schema.sql
--   supabase/migrations/20261107000700_approval_workflow.sql
--   automation/src/nodes/01-alert-intake/create-incident.js
--
-- TWO PENDING REQUESTS / ONE INCIDENT / TWO DEMO RESTART PLAYBOOKS:
--   Migration 20261107000700 creates UNIQUE partial index
--   playbook_runs_one_active_per_incident_playbook (incident_id, playbook_id)
--   for pending_approval, approved, and running. Two pending runs for the SAME
--   incident and SAME playbook are therefore invalid. This seed uses two
--   distinct, enabled restart playbooks so both approvals can be pending.
--   Vishwa/Vinuka should confirm the mobile UI can distinguish both requests.
--
-- The actual APPROVER is NOT set on pending rows: approver_id is the DECISION
-- actor and is filled by decide_approval() at Approve / Reject time.
-- APPROVE and REJECT should be exercised separately by signing into the phone
-- as the existing admin demo account. No automated approval is made by seed.
--
-- Repeatable only WHILE BOTH approvals remain pending. A decided approval is
-- immutable; this script deliberately refuses to reset it. Restore an approved
-- disposable demo DB snapshot if the entire demo must be repeated.
-- Direct seed inserts do NOT emit the request_playbook_run() notifications,
-- incident timeline or request audit entries. Confirm UI behavior before demo.
-- =============================================================================

BEGIN;

-- IDs already provisioned by the team; no Auth/profile writes in this file.
-- requester (role=user):  59b56aa4-1019-48f9-817c-30f3d10ca1dc
-- approver  (role=admin): 50d6db16-e804-4481-8bc6-f8a7838bd387
--
-- Stable fixture IDs (different from actual Auth users):
-- incident:        d3310000-0000-4000-8000-000000000001
-- analysis:        d3320000-0000-4000-8000-000000000001
-- playbook approve:d3330000-0000-4000-8000-000000000001
-- playbook reject: d3330000-0000-4000-8000-000000000002
-- run approve:     d3340000-0000-4000-8000-000000000001
-- run reject:      d3340000-0000-4000-8000-000000000002
-- approval approve:d3350000-0000-4000-8000-000000000001
-- approval reject: d3350000-0000-4000-8000-000000000002

-- 0. Prerequisite checks. Fail without making any changes if users, roles or
-- approval workflow migration are missing in the selected database.
DO $preflight$
BEGIN
    IF to_regclass('public.incidents') IS NULL
       OR to_regclass('public.ai_analyses') IS NULL
       OR to_regclass('public.playbooks') IS NULL
       OR to_regclass('public.playbook_runs') IS NULL
       OR to_regclass('public.approvals') IS NULL
       OR to_regclass('public.profiles') IS NULL
       OR to_regclass('auth.users') IS NULL THEN
        RAISE EXCEPTION 'Missing core tables; review approved schema migrations first.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = 'approvals'
           AND column_name = 'playbook_run_id'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = 'playbook_runs'
           AND column_name = 'idempotency_key'
    ) OR to_regclass('public.playbook_runs_one_active_per_incident_playbook') IS NULL THEN
        RAISE EXCEPTION 'Migration 20261107000700 approval workflow is not fully present.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM auth.users u
          JOIN public.profiles p ON p.id = u.id
         WHERE u.id = '59b56aa4-1019-48f9-817c-30f3d10ca1dc'::uuid
           AND p.role = 'user'
    ) THEN
        RAISE EXCEPTION 'Expected requester Auth user/profile not found with role=user.';
    END IF;
    IF NOT EXISTS (
        SELECT 1
          FROM auth.users u
          JOIN public.profiles p ON p.id = u.id
         WHERE u.id = '50d6db16-e804-4481-8bc6-f8a7838bd387'::uuid
           AND p.role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Expected approver Auth user/profile not found with role=admin.';
    END IF;
    IF '59b56aa4-1019-48f9-817c-30f3d10ca1dc'::uuid =
       '50d6db16-e804-4481-8bc6-f8a7838bd387'::uuid THEN
        RAISE EXCEPTION 'Requester and approver must be different users.';
    END IF;
END;
$preflight$;

-- 1. Dedicated demo restart playbooks; NEVER modify an operational playbook.
-- Distinct playbook IDs avoid the unique active-run index collision.
INSERT INTO public.playbooks
    (id, name, description, action_type, enabled, requires_approval, configuration)
VALUES
    ('d3330000-0000-4000-8000-000000000001',
     'Demo: sample-app restart (APPROVE)',
     'Dedicated demo playbook for approving a sample-app restart.',
     'restart', true, true, '{}'::jsonb),
    ('d3330000-0000-4000-8000-000000000002',
     'Demo: sample-app restart (REJECT)',
     'Dedicated demo playbook for rejecting a sample-app restart.',
     'restart', true, true, '{}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- 2. One synthetic incident, visible to the requester who created it.
-- Workflow 01's currently reviewed incident-create node is blocked and does
-- not confirm a source value, so use Vishwa's permitted fallback 'manual'.
INSERT INTO public.incidents
    (id, title, description, service_name, severity, status, source,
     environment, created_by)
VALUES
    ('d3310000-0000-4000-8000-000000000001',
     'sample-app high error rate',
     'Synthetic demo scenario: 42% of HTTP requests returned 5xx; sample-app is unhealthy.',
     'sample-app', 'critical', 'investigating', 'manual', 'development',
     '59b56aa4-1019-48f9-817c-30f3d10ca1dc')
ON CONFLICT (id) DO NOTHING;

-- 3. Linked synthetic AI analysis (42% HTTP 5xx, confidence 0.80).
INSERT INTO public.ai_analyses
    (id, incident_id, model_name, summary, root_cause, severity,
     confidence, recommended_action, evidence, recommendations)
VALUES
    ('d3320000-0000-4000-8000-000000000001',
     'd3310000-0000-4000-8000-000000000001',
     'synthetic-demo',
     'Demo observation: sample-app HTTP 5xx error rate reached 42%, and the service is unhealthy.',
     'Demo hypothesis: an unhealthy sample-app/dependency is causing elevated HTTP 5xx responses; investigate the underlying failure.',
     'critical', 0.80, 'restart',
     '[{"type":"metric","name":"http_5xx_ratio","value":0.42,"unit":"ratio"},
       {"type":"health","service":"sample-app","status":"unhealthy"}]'::jsonb,
     '[{"action":"restart","target":"sample-app","requires_approval":true},
       {"action":"verify_recovery","target":"sample-app"}]'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- 4. Two independent pending runs; same requester and incident but DISTINCT
-- playbook IDs and idempotency keys. No approved_by/approved_at is set.
INSERT INTO public.playbook_runs
    (id, playbook_id, incident_id, requested_by, status,
     approval_required, request_payload, idempotency_key)
VALUES
    ('d3340000-0000-4000-8000-000000000001',
     'd3330000-0000-4000-8000-000000000001',
     'd3310000-0000-4000-8000-000000000001',
     '59b56aa4-1019-48f9-817c-30f3d10ca1dc',
     'pending_approval', true, '{"service_name":"sample-app"}'::jsonb,
     'group33-demo-approve-sample-app-restart'),
    ('d3340000-0000-4000-8000-000000000002',
     'd3330000-0000-4000-8000-000000000002',
     'd3310000-0000-4000-8000-000000000001',
     '59b56aa4-1019-48f9-817c-30f3d10ca1dc',
     'pending_approval', true, '{"service_name":"sample-app"}'::jsonb,
     'group33-demo-reject-sample-app-restart')
ON CONFLICT (id) DO NOTHING;

-- 5. Two separate 1:1 approvals. Approver remains NULL until the admin
-- decides using the app/backend decide_approval() flow (not via this seed).
INSERT INTO public.approvals
    (id, incident_id, playbook_run_id, requested_by, approver_id,
     status, comments)
VALUES
    ('d3350000-0000-4000-8000-000000000001',
     'd3310000-0000-4000-8000-000000000001',
     'd3340000-0000-4000-8000-000000000001',
     '59b56aa4-1019-48f9-817c-30f3d10ca1dc',
     NULL, 'pending', 'DEMO APPROVE: restart sample-app using mobile admin approval.'),
    ('d3350000-0000-4000-8000-000000000002',
     'd3310000-0000-4000-8000-000000000001',
     'd3340000-0000-4000-8000-000000000002',
     '59b56aa4-1019-48f9-817c-30f3d10ca1dc',
     NULL, 'pending', 'DEMO REJECT: reject a separate sample-app restart request.')
ON CONFLICT (id) DO NOTHING;

-- 6. Fail closed if any pre-existing fixed ID has changed, a request has
-- already been decided, or relationships/settings differ from the fixture.
DO $verify$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.incidents
         WHERE id = 'd3310000-0000-4000-8000-000000000001'::uuid
           AND title = 'sample-app high error rate'
           AND service_name = 'sample-app'
           AND severity = 'critical'
           AND status = 'investigating'
           AND source = 'manual'
           AND environment = 'development'
           AND created_by = '59b56aa4-1019-48f9-817c-30f3d10ca1dc'::uuid
    ) THEN
        RAISE EXCEPTION 'Demo incident missing or changed.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.ai_analyses
         WHERE id = 'd3320000-0000-4000-8000-000000000001'::uuid
           AND incident_id = 'd3310000-0000-4000-8000-000000000001'::uuid
           AND severity = 'critical'
           AND confidence = 0.80
           AND recommended_action = 'restart'
           AND jsonb_typeof(evidence) = 'array'
           AND jsonb_typeof(recommendations) = 'array'
    ) THEN
        RAISE EXCEPTION 'Demo AI analysis missing or changed.';
    END IF;

    IF (SELECT count(*) FROM public.playbooks
         WHERE id IN (
           'd3330000-0000-4000-8000-000000000001'::uuid,
           'd3330000-0000-4000-8000-000000000002'::uuid
         ) AND action_type = 'restart'
           AND enabled = true AND requires_approval = true
           AND configuration = '{}'::jsonb
    ) <> 2 THEN
        RAISE EXCEPTION 'Both enabled approval-required demo restart playbooks must exist.';
    END IF;

    IF (SELECT count(*) FROM public.playbook_runs
        WHERE ((id = 'd3340000-0000-4000-8000-000000000001'::uuid
                AND playbook_id = 'd3330000-0000-4000-8000-000000000001'::uuid
                AND idempotency_key = 'group33-demo-approve-sample-app-restart')
            OR (id = 'd3340000-0000-4000-8000-000000000002'::uuid
                AND playbook_id = 'd3330000-0000-4000-8000-000000000002'::uuid
                AND idempotency_key = 'group33-demo-reject-sample-app-restart'))
          AND incident_id = 'd3310000-0000-4000-8000-000000000001'::uuid
          AND requested_by = '59b56aa4-1019-48f9-817c-30f3d10ca1dc'::uuid
          AND status = 'pending_approval'
          AND approval_required = true
          AND approved_by IS NULL AND approved_at IS NULL
          AND request_payload = '{"service_name":"sample-app"}'::jsonb
    ) <> 2 THEN
        RAISE EXCEPTION 'Both pending playbook runs must match the fixture.';
    END IF;

    IF (SELECT count(*) FROM public.approvals
        WHERE id IN (
          'd3350000-0000-4000-8000-000000000001'::uuid,
          'd3350000-0000-4000-8000-000000000002'::uuid
        )
          AND incident_id = 'd3310000-0000-4000-8000-000000000001'::uuid
          AND requested_by = '59b56aa4-1019-48f9-817c-30f3d10ca1dc'::uuid
          AND approver_id IS NULL AND status = 'pending'
          AND decided_at IS NULL
          AND playbook_run_id IN (
            'd3340000-0000-4000-8000-000000000001'::uuid,
            'd3340000-0000-4000-8000-000000000002'::uuid
          )
    ) <> 2 THEN
        RAISE EXCEPTION 'Both linked approvals must be pending and undecided.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.approvals a
        WHERE a.id = 'd3350000-0000-4000-8000-000000000001'::uuid
          AND a.playbook_run_id = 'd3340000-0000-4000-8000-000000000001'::uuid
    ) OR NOT EXISTS (
        SELECT 1 FROM public.approvals a
        WHERE a.id = 'd3350000-0000-4000-8000-000000000002'::uuid
          AND a.playbook_run_id = 'd3340000-0000-4000-8000-000000000002'::uuid
    ) THEN
        RAISE EXCEPTION 'Approval/run pairings changed or are incomplete.';
    END IF;
END;
$verify$;

COMMIT;

-- For Vinuka: optional post-apply verification ONLY after approval:
-- SELECT a.id AS approval_id, a.status AS approval_status, a.requested_by,
--        a.approver_id, r.id AS run_id, r.status AS run_status,
--        p.name AS playbook_name, p.action_type, p.enabled,
--        i.title, i.service_name, i.status AS incident_status
--   FROM public.approvals a
--   JOIN public.playbook_runs r ON r.id = a.playbook_run_id
--   JOIN public.playbooks p ON p.id = r.playbook_id
--   JOIN public.incidents i ON i.id = a.incident_id
--  WHERE a.id IN (
--    'd3350000-0000-4000-8000-000000000001'::uuid,
--    'd3350000-0000-4000-8000-000000000002'::uuid
--  ) ORDER BY a.id;
