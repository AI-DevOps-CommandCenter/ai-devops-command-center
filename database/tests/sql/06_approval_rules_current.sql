-- 06: Approval rules (A3, migration 000700).
--     One approval per playbook run; deciders are admins and operators, never
--     for their own request (A3-Q1); decisions are immutable for every role.
BEGIN;

SELECT tests.remember('u1',   tests.create_user('t06.u1@example.test', 'user'));
SELECT tests.remember('op',   tests.create_user('t06.op@example.test', 'operator'));
SELECT tests.remember('bot',  tests.create_user('t06.bot@example.test', 'automation'));
SELECT tests.remember('adm',  'a0000000-0000-4000-8000-000000000001');

-- u1 raises an incident and requests a restart.
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
INSERT INTO public.incidents (id, title, service_name, created_by)
VALUES ('c0600000-0000-4000-8000-000000000001', 'u1 incident', 'svc', tests.fx('u1'));
SELECT set_config('fx.req', public.request_playbook_run(
    'c0600000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001')::text, true);
SELECT tests.remember('appr', (current_setting('fx.req')::jsonb ->> 'approval_id')::uuid);
SELECT tests.remember('run',  (current_setting('fx.req')::jsonb ->> 'run_id')::uuid);

SELECT tests.is((SELECT playbook_run_id FROM public.approvals WHERE id = tests.fx('appr')), tests.fx('run'),
    'the request created one approval linked to its run (1:1)');
SELECT tests.is((SELECT status FROM public.playbook_runs WHERE id = tests.fx('run')), 'pending_approval',
    'the run waits for approval');
SELECT tests.throws(format($$UPDATE public.approvals SET status = 'approved' WHERE id = %L$$, tests.fx('appr')),
    '42501', 'clients cannot update approvals directly (A2-Q3)');
SELECT tests.throws(format($$SELECT public.decide_approval(%L, 'approved')$$, tests.fx('appr')),
    'DC403', 'a user cannot decide approvals');
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.approvals'), 1::bigint,
    'a user sees only their own approval requests');
RESET ROLE;

-- Automation never decides.
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.decide_approval(%L, 'approved')$$, tests.fx('appr')),
    'DC403', 'the automation identity cannot decide approvals');
RESET ROLE;

-- An operator decides (A3-Q1).
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.approvals'), 2::bigint,
    'operators see all approval requests (seeded + new)');
SELECT tests.throws(format($$SELECT public.decide_approval(%L, 'maybe')$$, tests.fx('appr')),
    'DC422', 'the decision must be approved or rejected');
SELECT tests.lives(format($$SELECT public.decide_approval(%L, 'approved', 'Safe to restart')$$, tests.fx('appr')),
    'an operator approves another user''s request');
RESET ROLE;

SELECT tests.is((SELECT approver_id FROM public.approvals WHERE id = tests.fx('appr')), tests.fx('op'),
    'the approver is taken from the JWT');
SELECT tests.is((SELECT status || '/' || approved_by::text FROM public.playbook_runs WHERE id = tests.fx('run')),
    'approved/' || tests.fx('op')::text, 'the linked run is approved by the same person');

SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.decide_approval(%L, 'rejected')$$, tests.fx('appr')),
    'DC409', 'a decided approval cannot be decided again');
RESET ROLE;

-- Immutable for the owner too.
SELECT tests.clear_claims();
SELECT tests.throws(format($$UPDATE public.approvals SET status = 'rejected' WHERE id = %L$$, tests.fx('appr')),
    'DC409', 'the owner cannot change a decided approval');
SELECT tests.throws(format($$DELETE FROM public.approvals WHERE id = %L$$, tests.fx('appr')),
    'DC409', 'the owner cannot delete a decided approval');
SELECT tests.throws($$TRUNCATE public.approvals CASCADE$$, 'DC403', 'approvals cannot be truncated');
-- Blocked twice over: the decided approval (DC409) and the timeline (RESTRICT).
SELECT tests.throws($$DELETE FROM public.incidents WHERE id = 'c0600000-0000-4000-8000-000000000001'$$,
    NULL, 'an incident with decided approvals and history cannot be hard-deleted');

-- Separation of duties: an operator's own request.
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT set_config('fx.req2', public.request_playbook_run(
    'c0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000003')::text, true);
SELECT tests.remember('appr2', (current_setting('fx.req2')::jsonb ->> 'approval_id')::uuid);
SELECT tests.throws(format($$SELECT public.decide_approval(%L, 'approved')$$, tests.fx('appr2')),
    'DC403', 'an operator cannot approve their own request');
RESET ROLE;
SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
SELECT tests.lives(format($$SELECT public.decide_approval(%L, 'rejected', 'Not now')$$, tests.fx('appr2')),
    'an admin rejects the operator''s request');
RESET ROLE;
SELECT tests.is((SELECT status FROM public.playbook_runs
                 WHERE id = (current_setting('fx.req2')::jsonb ->> 'run_id')::uuid),
    'rejected', 'rejecting the approval rejects the run');

-- The seeded legacy approval (requested by the only original admin, no run).
SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.decide_approval('f1000000-0000-4000-8000-000000000001', 'approved')$$,
    'DC403', 'the admin still cannot approve their own legacy request');
RESET ROLE;
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.lives($$SELECT public.decide_approval('f1000000-0000-4000-8000-000000000001', 'rejected', 'Legacy')$$,
    'an operator can now decide the legacy deadlocked request (A3-Q1; whether to do so is A3-Q2)');
RESET ROLE;

ROLLBACK;
