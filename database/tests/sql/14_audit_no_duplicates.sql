-- 14: Exactly one audit entry per action (backend RPC integration).
--     The backend no longer writes audit_logs; the workflow functions
--     (000700) and the triggers (000800) must together produce exactly ONE
--     entry per action: no duplicates and no gaps.
BEGIN;

SELECT tests.remember('u1',  tests.create_user('t14.u1@example.test', 'user'));
SELECT tests.remember('op',  tests.create_user('t14.op@example.test', 'operator'));
SELECT tests.remember('bot', tests.create_user('t14.bot@example.test', 'automation'));

-- Audit entries for one entity, counted as the owner (no RLS).
CREATE FUNCTION tests.audit_count(p_entity uuid) RETURNS bigint
    LANGUAGE sql AS $$ SELECT count(*) FROM public.audit_logs WHERE entity_id = p_entity $$;
CREATE FUNCTION tests.audit_actions(p_entity uuid) RETURNS text
    LANGUAGE sql AS $$
    SELECT string_agg(action, ',' ORDER BY action) FROM public.audit_logs WHERE entity_id = p_entity $$;

-- Incident created through the API (trigger).
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
INSERT INTO public.incidents (id, title, service_name, created_by)
VALUES ('c1400000-0000-4000-8000-000000000001', 'u1 incident', 'svc', tests.fx('u1'));
RESET ROLE;
SELECT tests.is(tests.audit_actions('c1400000-0000-4000-8000-000000000001'), 'INCIDENT_CREATED',
    'incident creation: exactly one entry');

-- Request (function writes the approval + run; only the function audits).
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT set_config('fx.r', public.request_playbook_run('c1400000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000001')::text, true);
RESET ROLE;
SELECT tests.remember('run',  (current_setting('fx.r')::jsonb ->> 'run_id')::uuid);
SELECT tests.remember('appr', (current_setting('fx.r')::jsonb ->> 'approval_id')::uuid);
SELECT tests.is(tests.audit_actions(tests.fx('run')), 'PLAYBOOK_RUN_REQUESTED',
    'run request: exactly one entry for the run');
SELECT tests.is(tests.audit_count(tests.fx('appr')), 0::bigint,
    'run request: no separate entry for the approval row it created');

-- Decision (function updates approval + run; one entry).
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT public.decide_approval(tests.fx('appr'), 'approved', 'ok');
RESET ROLE;
SELECT tests.is(tests.audit_actions(tests.fx('appr')), 'APPROVAL_APPROVED',
    'decision: exactly one entry for the approval');
SELECT tests.is(tests.audit_actions(tests.fx('run')), 'PLAYBOOK_RUN_REQUESTED',
    'decision: no extra entry for the run it moved to approved');

-- Start + complete by automation (automation_runs writes are not audited twice).
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT public.start_playbook_run(tests.fx('run'), 'n8n-14-001');
SELECT public.complete_playbook_run(tests.fx('run'), 'success', '{}', 'n8n-14-001');
RESET ROLE;
SELECT tests.is(tests.audit_actions(tests.fx('run')),
    'PLAYBOOK_RUN_COMPLETED,PLAYBOOK_RUN_REQUESTED,PLAYBOOK_RUN_STARTED',
    'start and complete: exactly one entry each');

-- Incident status change by a manager (trigger), one entry per real change.
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
UPDATE public.incidents SET status = 'identified' WHERE id = 'c1400000-0000-4000-8000-000000000001';
UPDATE public.incidents SET status = 'identified' WHERE id = 'c1400000-0000-4000-8000-000000000001';
RESET ROLE;
SELECT tests.is(tests.audit_actions('c1400000-0000-4000-8000-000000000001'),
    'INCIDENT_CREATED,INCIDENT_UPDATED',
    'status change: one entry; a no-op update adds none');

-- Cancel path: one entry.
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT set_config('fx.r2', public.request_playbook_run('c1400000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000002')::text, true);
SELECT public.cancel_playbook_run((current_setting('fx.r2')::jsonb ->> 'run_id')::uuid, 'not needed');
RESET ROLE;
SELECT tests.is(tests.audit_actions((current_setting('fx.r2')::jsonb ->> 'run_id')::uuid),
    'PLAYBOOK_RUN_CANCELLED,PLAYBOOK_RUN_REQUESTED',
    'cancel: exactly one entry');

-- A failed action leaves no audit entry at all.
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.request_playbook_run('c1400000-0000-4000-8000-000000000001',
                      'e0000000-0000-4000-8000-000000000004')$$,
    'DC409', 'requesting a disabled playbook fails');
RESET ROLE;
SELECT tests.is((SELECT count(*) FROM public.audit_logs
                 WHERE details ->> 'playbook_id' = 'e0000000-0000-4000-8000-000000000004'), 0::bigint,
    'the failed request wrote no audit entry');

ROLLBACK;
