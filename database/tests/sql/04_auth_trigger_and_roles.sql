-- 04: Sign-up trigger, updated_at trigger and the role-change function.
BEGIN;

SELECT tests.remember('new_user', tests.create_user('t04.user@example.test', 'user'));
SELECT tests.remember('admin', 'a0000000-0000-4000-8000-000000000001');
SELECT tests.remember('operator', 'a0000000-0000-4000-8000-000000000002');

SELECT tests.is(
    (SELECT email FROM public.profiles WHERE id = tests.fx('new_user')),
    't04.user@example.test', 'sign-up creates a profile with the auth email');
SELECT tests.is(
    (SELECT full_name FROM public.profiles WHERE id = tests.fx('new_user')),
    'Synthetic user', 'full_name is copied from auth metadata');

INSERT INTO auth.users (email) VALUES ('t04.default@example.test');
SELECT tests.is(
    (SELECT role FROM public.profiles WHERE email = 't04.default@example.test'),
    'user', 'new sign-ups default to role user');

UPDATE public.profiles SET updated_at = '2000-01-01' WHERE id = tests.fx('new_user');
UPDATE public.profiles SET full_name = 'Changed' WHERE id = tests.fx('new_user');
SELECT tests.ok(
    (SELECT updated_at > now() - interval '1 minute' FROM public.profiles WHERE id = tests.fx('new_user')),
    'set_updated_at refreshes updated_at on update');

-- admin_update_user_role (SECURITY DEFINER, internal checks)
SELECT tests.login('admin');
SET LOCAL ROLE authenticated;
SELECT tests.lives(format($$SELECT public.admin_update_user_role(%L, 'operator')$$, tests.fx('new_user')),
    'admin can change another user''s role');
SELECT tests.throws(format($$SELECT public.admin_update_user_role(%L, 'user')$$, tests.fx('admin')),
    'P0001', 'admin cannot change their own role');
SELECT tests.throws(format($$SELECT public.admin_update_user_role(%L, 'automation')$$, tests.fx('new_user')),
    'P0001', 'role function rejects values outside user/admin/operator');
RESET ROLE;
SELECT tests.is((SELECT role FROM public.profiles WHERE id = tests.fx('new_user')), 'operator',
    'role change was applied');

SELECT tests.login('operator');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.admin_update_user_role(%L, 'admin')$$, tests.fx('new_user')),
    'P0001', 'non-admins cannot change roles');
SELECT tests.throws(format($$UPDATE public.profiles SET role = 'admin' WHERE id = %L$$, tests.fx('operator')),
    '42501', 'users cannot update profiles directly (no UPDATE grant: no self-escalation)');
RESET ROLE;

SELECT tests.clear_claims();
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.admin_update_user_role(%L, 'admin')$$, tests.fx('new_user')),
    'P0001', 'role function requires an authenticated caller');
RESET ROLE;

SET LOCAL ROLE anon;
SELECT tests.throws(format($$SELECT public.admin_update_user_role(%L, 'admin')$$, tests.fx('new_user')),
    '42501', 'anon cannot execute the role function');
RESET ROLE;

ROLLBACK;
