-- =============================================================================
-- SYNTHETIC seed data (decision D-007). Local and staging databases only.
--
-- * Every value is invented. Nothing here comes from production; no real
--   names, emails, IDs or credentials.
-- * The per-table row counts mirror the production SHAPE (46 rows across the
--   same 10 tables), so migration and preservation tests exercise realistic
--   cases:
--     - a pending approval requested by the only admin (approval deadlock);
--     - a pending playbook run without an approval row;
--     - a legacy remediation execution marked succeeded with no approval;
--     - an enabled restart playbook that does not require approval;
--     - incidents with a free-text service_name and no service_id;
--     - 24 audit entries.
-- * The seed users cannot sign in (no password or identity). For a local
--   login, create a user in Supabase Studio and set its role with SQL; see
--   database/DATABASE_TEAM_HANDOVER.md.
--
-- Applied automatically by `supabase db reset` (config.toml [db.seed]) and by
-- database/tests/run-local-db-tests.sh. NEVER run it on production.
-- =============================================================================

-- Users: inserting into auth.users fires on_auth_user_created, which creates
-- the profiles (default role 'user'); the roles are then set below.
INSERT INTO auth.users (id, email, raw_user_meta_data) VALUES
    ('a0000000-0000-4000-8000-000000000001', 'synthetic.admin@example.test',
        '{"full_name": "Synthetic Admin"}'),
    ('a0000000-0000-4000-8000-000000000002', 'synthetic.operator@example.test',
        '{"full_name": "Synthetic Operator"}');

UPDATE public.profiles SET role = 'admin'
WHERE id = 'a0000000-0000-4000-8000-000000000001';
UPDATE public.profiles SET role = 'operator'
WHERE id = 'a0000000-0000-4000-8000-000000000002';

INSERT INTO public.services (id, name, description, environment, endpoint, status) VALUES
    ('b0000000-0000-4000-8000-000000000001', 'synthetic-checkout-api',
        'Synthetic checkout service', 'staging', 'https://checkout.example.test/health', 'healthy'),
    ('b0000000-0000-4000-8000-000000000002', 'synthetic-orders-api',
        'Synthetic orders service', 'staging', 'https://orders.example.test/health', 'degraded');

-- Incidents use the free-text service_name only (service_id NULL), as the
-- current backend does.
INSERT INTO public.incidents
    (id, title, description, severity, status, source, created_by, environment, service_name)
VALUES
    ('c0000000-0000-4000-8000-000000000001', 'Synthetic: checkout latency spike',
        'p95 latency above threshold', 'high', 'investigating', 'manual',
        'a0000000-0000-4000-8000-000000000001', 'staging', 'synthetic-checkout-api'),
    ('c0000000-0000-4000-8000-000000000002', 'Synthetic: orders error rate',
        '5xx rate above 2%', 'critical', 'open', 'manual',
        'a0000000-0000-4000-8000-000000000002', 'staging', 'synthetic-orders-api'),
    ('c0000000-0000-4000-8000-000000000003', 'Synthetic: resolved cache miss storm',
        'Cache warmed manually', 'medium', 'resolved', 'manual',
        'a0000000-0000-4000-8000-000000000001', 'staging', 'Synthetic Free Text Service');

INSERT INTO public.investigations (id, incident_id, status, summary, root_cause, ai_model) VALUES
    ('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
        'completed', 'Synthetic summary A', 'Synthetic root cause A', 'synthetic-model'),
    ('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001',
        'running', NULL, NULL, NULL),
    ('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000002',
        'pending', NULL, NULL, NULL),
    ('d0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000003',
        'completed', 'Synthetic summary D', 'Synthetic root cause D', 'synthetic-model');

-- One playbook per allowed action type, plus an enabled restart playbook
-- that requires NO approval (the A4 case).
INSERT INTO public.playbooks (id, name, description, action_type, enabled, requires_approval) VALUES
    ('e0000000-0000-4000-8000-000000000001', 'Synthetic Restart', 'Restart a service', 'restart', true, true),
    ('e0000000-0000-4000-8000-000000000002', 'Synthetic Rollback', 'Roll back a deployment', 'rollback', true, true),
    ('e0000000-0000-4000-8000-000000000003', 'Synthetic Scale', 'Scale a service', 'scale', true, true),
    ('e0000000-0000-4000-8000-000000000004', 'Synthetic Circuit Breaker', 'Open a circuit breaker', 'circuit_breaker', false, true),
    ('e0000000-0000-4000-8000-000000000005', 'Synthetic No-Approval Restart', 'Restart without approval', 'restart', true, false);

-- Pending run without an approval row (different incident from the approval).
INSERT INTO public.playbook_runs
    (id, playbook_id, incident_id, requested_by, status, approval_required, request_payload)
VALUES
    ('f0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001',
        'c0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002',
        'pending_approval', true, '{"reason": "synthetic"}');

-- Pending approval requested by the only admin (nobody can decide it today).
INSERT INTO public.approvals (id, incident_id, requested_by, status, comments) VALUES
    ('f1000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000001', 'pending', 'Synthetic approval request');

-- Legacy remediation marked succeeded with no approval and no recovery check.
INSERT INTO public.remediation_executions
    (id, incident_id, playbook_id, triggered_by, status, input_data, output_data, started_at, completed_at)
VALUES
    ('f2000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
        'e0000000-0000-4000-8000-000000000005', 'a0000000-0000-4000-8000-000000000001',
        'succeeded', '{"target": "synthetic-checkout-api"}', '{"result": "restarted"}',
        now() - interval '2 hours', now() - interval '2 hours' + interval '1 minute');

INSERT INTO public.postmortems (id, incident_id, summary, root_cause, impact, created_by) VALUES
    ('f3000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
        'Synthetic postmortem A', 'Synthetic cause', 'Synthetic impact', 'a0000000-0000-4000-8000-000000000001'),
    ('f3000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000002',
        'Synthetic postmortem B', NULL, NULL, 'a0000000-0000-4000-8000-000000000002'),
    ('f3000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000003',
        'Synthetic postmortem C', 'Synthetic cause', NULL, 'a0000000-0000-4000-8000-000000000001');

-- 24 synthetic audit entries.
INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, details, created_at)
SELECT
    CASE WHEN g % 2 = 0 THEN 'a0000000-0000-4000-8000-000000000001'::uuid
         ELSE 'a0000000-0000-4000-8000-000000000002'::uuid END,
    (ARRAY['INCIDENT_CREATED', 'INCIDENT_UPDATED', 'PLAYBOOK_RUN_REQUESTED', 'POSTMORTEM_CREATED'])[1 + g % 4],
    'incident',
    'c0000000-0000-4000-8000-000000000001'::uuid,
    jsonb_build_object('synthetic', true, 'sequence', g),
    now() - make_interval(mins => 60 - g)
FROM generate_series(1, 24) AS g;
