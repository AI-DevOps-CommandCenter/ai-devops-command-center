-- 05: Row Level Security for users, operators, admins and anon, using the
--     user's JWT (as the backend does with its per-request client).
BEGIN;

SELECT tests.remember('u1', tests.create_user('t05.u1@example.test', 'user'));
SELECT tests.remember('u2', tests.create_user('t05.u2@example.test', 'user'));
SELECT tests.remember('op', tests.create_user('t05.op@example.test', 'operator'));
SELECT tests.remember('adm', 'a0000000-0000-4000-8000-000000000001');

-- Incidents
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.lives(format($$INSERT INTO public.incidents (id, title, service_name, created_by)
                            VALUES ('c0500000-0000-4000-8000-000000000001', 'u1 incident', 'svc', %L)$$, tests.fx('u1')),
    'user creates their own incident');
SELECT tests.throws(format($$INSERT INTO public.incidents (title, service_name, created_by)
                             VALUES ('spoofed', 'svc', %L)$$, tests.fx('u2')),
    '42501', 'user cannot create an incident on behalf of another user');
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.incidents'), 1::bigint,
    'user sees only their own incidents');
SELECT tests.is(tests.affected($$UPDATE public.incidents SET status = 'resolved'
                                 WHERE id = 'c0500000-0000-4000-8000-000000000001'$$), 0::bigint,
    'user cannot update incidents (managers only)');
SELECT tests.throws($$DELETE FROM public.incidents$$, '42501', 'nobody can delete incidents via the API (no DELETE grant)');
RESET ROLE;

SELECT tests.login('u2');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.incidents'), 0::bigint,
    'another user cannot see u1''s incident');
RESET ROLE;

SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.incidents'), 4::bigint,
    'operator sees all incidents (3 seeded + 1)');
SELECT tests.is(tests.affected($$UPDATE public.incidents SET status = 'identified'
                                 WHERE id = 'c0500000-0000-4000-8000-000000000001'$$), 1::bigint,
    'operator can update incidents');
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.audit_logs'), 0::bigint,
    'operators cannot read audit logs');
RESET ROLE;

-- Investigations follow incident ownership
SELECT tests.login('u2');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$INSERT INTO public.investigations (incident_id) VALUES ('c0500000-0000-4000-8000-000000000001')$$,
    '42501', 'user cannot add an investigation to someone else''s incident');
RESET ROLE;
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.lives($$INSERT INTO public.investigations (incident_id) VALUES ('c0500000-0000-4000-8000-000000000001')$$,
    'user can add an investigation to their own incident');
RESET ROLE;

-- Audit logs
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.audit_logs'), 0::bigint,
    'users cannot read audit logs');
SELECT tests.throws(format($$INSERT INTO public.audit_logs (actor_id, action) VALUES (%L, 'X')$$, tests.fx('u2')),
    '42501', 'users cannot write audit entries for another actor');
SELECT tests.throws($$UPDATE public.audit_logs SET action = 'tampered'$$, '42501', 'clients cannot update audit logs');
SELECT tests.throws($$DELETE FROM public.audit_logs$$, '42501', 'clients cannot delete audit logs');
SELECT tests.throws($$TRUNCATE public.audit_logs$$, '42501', 'clients cannot truncate audit logs');
RESET ROLE;

SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
-- 24 seeded + INCIDENT_CREATED (u1) + INCIDENT_UPDATED (op) written by the
-- audit triggers of migration 000800.
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.audit_logs'), 26::bigint,
    'admins can read audit logs (incl. the 2 entries audited by this test)');
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.profiles'), 5::bigint,
    'admins can read all profiles');
RESET ROLE;

-- Profiles
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.profiles'), 1::bigint,
    'users can read only their own profile');
RESET ROLE;

-- Playbooks
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.playbooks'), 4::bigint,
    'users see enabled playbooks only (4 of 5)');
SELECT tests.throws($$INSERT INTO public.playbooks (name, action_type) VALUES ('rogue', 'restart')$$,
    '42501', 'users cannot create playbooks');
RESET ROLE;
SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.playbooks'), 5::bigint,
    'admins see all playbooks');
RESET ROLE;

-- Remediation executions: managers only
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$INSERT INTO public.remediation_executions (incident_id, status)
                      VALUES ('c0500000-0000-4000-8000-000000000001', 'running')$$,
    '42501', 'a user without permission cannot record a remediation execution');
RESET ROLE;

-- Tables without client grants
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT 1 FROM public.services$$, '42501', 'services: no client access today (R5 pending)');
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.notifications'), 0::bigint,
    'notifications: users read their own inbox only (A6; empty here)');
SELECT tests.throws(format($$INSERT INTO public.device_tokens (user_id, device_token, platform)
                             VALUES (%L, 'tok-u1', 'android')$$, tests.fx('u1')),
    '42501', 'device_tokens: no direct INSERT; register through register_device_token() (A6)');
RESET ROLE;

-- anon
SET LOCAL ROLE anon;
SELECT tests.throws($$SELECT 1 FROM public.incidents$$, '42501', 'anon cannot read incidents');
SELECT tests.throws($$SELECT 1 FROM public.profiles$$, '42501', 'anon cannot read profiles');
RESET ROLE;

ROLLBACK;
