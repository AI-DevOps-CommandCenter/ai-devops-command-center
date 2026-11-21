-- 13: Audit coverage of direct writes and payload redaction (migration 000800).
BEGIN;

SELECT tests.remember('u1',  tests.create_user('t13.u1@example.test', 'user'));
SELECT tests.remember('u2',  tests.create_user('t13.u2@example.test', 'user'));
SELECT tests.remember('op',  tests.create_user('t13.op@example.test', 'operator'));
SELECT tests.remember('bot', tests.create_user('t13.bot@example.test', 'automation'));
SELECT tests.remember('adm', 'a0000000-0000-4000-8000-000000000001');

-- #1 Incidents: create and status change through the API are audited.
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
INSERT INTO public.incidents (id, title, service_name, created_by)
VALUES ('c1300000-0000-4000-8000-000000000001', 'u1 incident', 'svc', tests.fx('u1'));
RESET ROLE;
SELECT tests.ok(EXISTS (SELECT 1 FROM public.audit_logs
                        WHERE action = 'INCIDENT_CREATED' AND entity_id = 'c1300000-0000-4000-8000-000000000001'
                          AND actor_id = tests.fx('u1') AND details ->> 'actor_role' = 'user'),
    'incident creation is audited with the creator as actor');

SELECT tests.login('op');
SET LOCAL ROLE authenticated;
UPDATE public.incidents SET status = 'investigating' WHERE id = 'c1300000-0000-4000-8000-000000000001';
UPDATE public.incidents SET updated_at = now() WHERE id = 'c1300000-0000-4000-8000-000000000001';
RESET ROLE;
SELECT tests.ok(EXISTS (SELECT 1 FROM public.audit_logs
                        WHERE action = 'INCIDENT_UPDATED' AND entity_id = 'c1300000-0000-4000-8000-000000000001'
                          AND actor_id = tests.fx('op')
                          AND details ->> 'old_status' = 'open' AND details ->> 'status' = 'investigating'
                          AND details -> 'changed' ? 'status'),
    'a status change is audited with old and new value');
SELECT tests.is((SELECT count(*) FROM public.audit_logs
                 WHERE action = 'INCIDENT_UPDATED' AND entity_id = 'c1300000-0000-4000-8000-000000000001'),
    1::bigint, 'an update that changes nothing but updated_at is not audited');
SELECT tests.is((SELECT message FROM public.incident_events
                 WHERE incident_id = 'c1300000-0000-4000-8000-000000000001' AND event_type = 'status_change'),
    'Status open -> investigating', 'the status change is on the timeline');

-- Owner maintenance (no JWT) is out of scope.
SELECT tests.clear_claims();
INSERT INTO public.incidents (id, title) VALUES ('c1300000-0000-4000-8000-000000000002', 'owner insert');
SELECT tests.ok(NOT EXISTS (SELECT 1 FROM public.audit_logs WHERE entity_id = 'c1300000-0000-4000-8000-000000000002'),
    'owner changes without a JWT are not written to the application audit log');

-- Postmortems
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
INSERT INTO public.postmortems (id, incident_id, summary, created_by)
VALUES ('f1300000-0000-4000-8000-000000000001', 'c1300000-0000-4000-8000-000000000001', 'Synthetic', tests.fx('op'));
RESET ROLE;
SELECT tests.ok(EXISTS (SELECT 1 FROM public.audit_logs WHERE action = 'POSTMORTEM_CREATED'
                          AND entity_id = 'f1300000-0000-4000-8000-000000000001' AND actor_id = tests.fx('op')),
    'postmortem creation is audited');

-- Playbook and integration administration; integration settings never reach the audit log.
SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
INSERT INTO public.playbooks (id, name, action_type) VALUES ('e1300000-0000-4000-8000-000000000001', 't13 playbook', 'scale');
UPDATE public.playbooks SET enabled = true WHERE id = 'e1300000-0000-4000-8000-000000000001';
DELETE FROM public.playbooks WHERE id = 'e1300000-0000-4000-8000-000000000001';
INSERT INTO public.integrations (id, name, provider, settings)
VALUES ('e1300000-0000-4000-8000-000000000002', 't13 github', 'github', '{"webhook_url": "https://hooks.example.test/x", "token": "should-not-leak"}');
SELECT tests.lives(format($$SELECT public.admin_update_user_role(%L, 'operator')$$, tests.fx('u2')),
    'admin changes a role');
RESET ROLE;
SELECT tests.is((SELECT string_agg(action, ',' ORDER BY action) FROM public.audit_logs
                 WHERE entity_id = 'e1300000-0000-4000-8000-000000000001'),
    'PLAYBOOK_CREATED,PLAYBOOK_DELETED,PLAYBOOK_UPDATED', 'playbook create, update and delete are audited');
SELECT tests.is((SELECT details ->> 'enabled' FROM public.audit_logs
                 WHERE entity_id = 'e1300000-0000-4000-8000-000000000001' AND action = 'PLAYBOOK_UPDATED'),
    'true', 'the playbook audit records the changed flag');
SELECT tests.ok(EXISTS (SELECT 1 FROM public.audit_logs WHERE action = 'INTEGRATION_CREATED'
                          AND entity_id = 'e1300000-0000-4000-8000-000000000002' AND actor_id = tests.fx('adm')),
    'integration creation is audited');
SELECT tests.ok(NOT EXISTS (SELECT 1 FROM public.audit_logs
                            WHERE details::text LIKE '%should-not-leak%' OR details::text LIKE '%hooks.example.test%'),
    'integration settings never reach the audit log');
SELECT tests.ok(EXISTS (SELECT 1 FROM public.audit_logs WHERE action = 'USER_ROLE_UPDATED'
                          AND entity_id = tests.fx('u2') AND actor_id = tests.fx('adm')
                          AND details ->> 'old_role' = 'user' AND details ->> 'role' = 'operator'),
    'role changes are audited with the admin as actor and old/new role');

-- Fail closed: if the audit entry cannot be written, the direct write fails too.
CREATE FUNCTION tests.break_audit13() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'audit store unavailable'; END $$;
CREATE TRIGGER zz_break_audit13 BEFORE INSERT ON public.audit_logs
    FOR EACH ROW EXECUTE FUNCTION tests.break_audit13();
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$INSERT INTO public.incidents (id, title, created_by)
                             VALUES ('c1300000-0000-4000-8000-000000000003', 'x', %L)$$, tests.fx('u1')),
    'P0001', 'when the audit write fails, the incident is not created');
RESET ROLE;
DROP TRIGGER zz_break_audit13 ON public.audit_logs;
SELECT tests.ok(NOT EXISTS (SELECT 1 FROM public.incidents WHERE id = 'c1300000-0000-4000-8000-000000000003'),
    'ATOMIC: no incident without its audit entry');

-- #2 Redaction at any depth, for run payloads (all writers).
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT set_config('fx.r', public.request_playbook_run('c1300000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000001', NULL,
    '{"target": "svc", "api_key": "leak-1", "auth": {"bearer_token": "leak-2", "user": "ops"},
      "steps": [{"name": "restart", "password": "leak-3"}]}')::text, true);
SELECT tests.remember('run', (current_setting('fx.r')::jsonb ->> 'run_id')::uuid);
RESET ROLE;
SELECT tests.is((SELECT request_payload FROM public.playbook_runs WHERE id = tests.fx('run')),
    '{"target": "svc", "auth": {"user": "ops"}, "steps": [{"name": "restart"}]}'::jsonb,
    'credential-like keys are removed from the stored request at every depth');

SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT public.decide_approval((current_setting('fx.r')::jsonb ->> 'approval_id')::uuid, 'approved');
RESET ROLE;
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT public.start_playbook_run(tests.fx('run'), 'n8n-13-001');
SELECT public.complete_playbook_run(tests.fx('run'), 'failed',
    '{"error": "timeout", "debug": {"headers": {"Authorization": "leak-4"}}}', 'n8n-13-001');
RESET ROLE;
SELECT tests.is((SELECT input FROM public.automation_runs WHERE playbook_run_id = tests.fx('run')),
    '{"target": "svc", "auth": {"user": "ops"}, "steps": [{"name": "restart"}]}'::jsonb,
    'the automation record of the request is redacted too');
SELECT tests.is((SELECT result_payload FROM public.playbook_runs WHERE id = tests.fx('run')),
    '{"error": "timeout", "debug": {"headers": {}}}'::jsonb,
    'nested credentials are removed from the stored result');

SELECT tests.clear_claims();
INSERT INTO public.automation_runs (workflow_name, input) VALUES ('t13', '{"secret": "leak-5", "ok": 1}');
SELECT tests.is((SELECT input FROM public.automation_runs WHERE workflow_name = 't13'), '{"ok": 1}'::jsonb,
    'redaction also applies to owner writes');
SELECT tests.ok(NOT EXISTS (
        SELECT 1 FROM public.playbook_runs WHERE request_payload::text LIKE '%leak-%' OR result_payload::text LIKE '%leak-%'
        UNION ALL
        SELECT 1 FROM public.automation_runs WHERE input::text LIKE '%leak-%' OR output::text LIKE '%leak-%'
        UNION ALL
        SELECT 1 FROM public.audit_logs WHERE details::text LIKE '%leak-%'),
    'no test credential is stored anywhere');
SELECT tests.is(public.redact_sensitive('[{"token": 1, "a": 2}]'), '{"value": [{"a": 2}]}'::jsonb,
    'redact_sensitive is recursive for non-object input');

-- Internal functions are not callable by clients.
SELECT tests.ok(NOT has_function_privilege('authenticated', 'public.redact_json(jsonb)', 'EXECUTE')
            AND NOT has_function_privilege('authenticated', 'public.audit_row_change()', 'EXECUTE'),
    'the audit and redaction helpers have no client EXECUTE');

ROLLBACK;
