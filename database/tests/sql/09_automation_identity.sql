-- 09: Automation identity and replay protection (A5, migration 000400).
BEGIN;

SELECT tests.remember('u1',  tests.create_user('t09.u1@example.test', 'user'));
SELECT tests.remember('op',  tests.create_user('t09.op@example.test', 'operator'));
SELECT tests.remember('bot', tests.create_user('t09.bot@example.test', 'automation'));
SELECT tests.remember('adm', 'a0000000-0000-4000-8000-000000000001');

SELECT tests.is((SELECT role FROM public.profiles WHERE id = tests.fx('bot')), 'automation',
    'the database owner can provision the automation identity');

-- Nobody can move the automation role through the API.
SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.admin_update_user_role(%L, 'automation')$$, tests.fx('u1')),
    'P0001', 'admins cannot make a human the automation identity');
SELECT tests.throws(format($$SELECT public.admin_update_user_role(%L, 'admin')$$, tests.fx('bot')),
    'DC403', 'admins cannot give the automation identity a human role');
SELECT tests.throws(format($$SELECT public.admin_update_user_role(%L, 'user')$$, tests.fx('bot')),
    'DC403', 'admins cannot revoke the automation role through the API (owner procedure, A5-Q2)');
RESET ROLE;
SELECT tests.is((SELECT role FROM public.profiles WHERE id = tests.fx('bot')), 'automation',
    'the automation role is unchanged');

-- Who am I
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.is(public.current_app_role(), 'automation', 'current_app_role() reports automation');

-- Replay protection
SELECT tests.lives($$SELECT public.consume_automation_nonce('nonce-0000000000000001', now())$$,
    'a fresh signed request is accepted');
SELECT tests.throws($$SELECT public.consume_automation_nonce('nonce-0000000000000001', now())$$,
    'DC409', 'the same nonce cannot be used twice (replay)');
SELECT tests.throws($$SELECT public.consume_automation_nonce('nonce-0000000000000002', now() - interval '6 minutes')$$,
    'DC401', 'a request signed more than 5 minutes ago is rejected');
SELECT tests.throws($$SELECT public.consume_automation_nonce('nonce-0000000000000003', now() + interval '6 minutes')$$,
    'DC401', 'a request signed more than 5 minutes in the future is rejected');
SELECT tests.throws($$SELECT public.consume_automation_nonce('short', now())$$,
    'DC422', 'nonces must be at least 16 characters');
SELECT tests.throws($$SELECT 1 FROM public.automation_request_nonces$$,
    '42501', 'the nonce store is not readable by clients, not even the automation identity');

-- The automation identity never requests or decides.
SELECT tests.throws($$SELECT public.request_playbook_run('c0000000-0000-4000-8000-000000000002',
                                                          'e0000000-0000-4000-8000-000000000001')$$,
    'DC403', 'the automation identity cannot request remediation');
SELECT tests.throws($$SELECT public.decide_approval('f1000000-0000-4000-8000-000000000001', 'approved')$$,
    'DC403', 'the automation identity cannot decide approvals');
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.audit_logs'), 0::bigint,
    'the automation identity cannot read audit logs');
SELECT tests.throws($$SELECT public.start_playbook_run('f0000000-0000-4000-8000-000000000001', 'n8n-09-001')$$,
    'DC409', 'the automation identity cannot start a run that is not approved');
RESET ROLE;

-- Machine functions are automation-only.
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.consume_automation_nonce('nonce-0000000000000004', now())$$,
    'DC403', 'humans cannot use the machine nonce function');
RESET ROLE;
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.start_playbook_run('f0000000-0000-4000-8000-000000000001', 'n8n-09-002')$$,
    'DC403', 'humans cannot start runs (only n8n through the backend)');
RESET ROLE;

SELECT tests.clear_claims();
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.consume_automation_nonce('nonce-0000000000000005', now())$$,
    'DC401', 'an unauthenticated call is rejected');
RESET ROLE;
SET LOCAL ROLE anon;
SELECT tests.throws($$SELECT public.consume_automation_nonce('nonce-0000000000000006', now())$$,
    '42501', 'anon cannot execute machine functions');
RESET ROLE;

ROLLBACK;
