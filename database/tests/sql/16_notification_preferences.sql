-- 16: Per-user notification preferences (migration 20261118000100, mobile S27).
BEGIN;

SELECT tests.remember('u1',  tests.create_user('t16.u1@example.test', 'user'));
SELECT tests.remember('u2',  tests.create_user('t16.u2@example.test', 'operator'));
SELECT tests.remember('u3',  tests.create_user('t16.u3@example.test', 'user'));
SELECT tests.remember('bot', tests.create_user('t16.bot@example.test', 'automation'));

-- Structure and access
SELECT tests.ok((SELECT rowsecurity FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notification_preferences'),
    'notification_preferences has RLS enabled');
SELECT tests.is((SELECT string_agg(cmd, ',') FROM pg_policies WHERE schemaname = 'public' AND tablename = 'notification_preferences'),
    'SELECT', 'the only policy is an own-row read; writes go through the function');
SELECT tests.ok(NOT has_function_privilege('anon', 'public.set_notification_preferences(boolean, boolean)', 'EXECUTE'),
    'anon cannot save preferences');
SELECT tests.ok(NOT has_function_privilege('authenticated', 'public.write_notification(uuid, uuid, text, text, text[])', 'EXECUTE'),
    'write_notification stays internal');

-- Defaults without a row
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.is((SELECT push_enabled FROM public.get_notification_preferences()), true, 'default: push on');
SELECT tests.is((SELECT email_enabled FROM public.get_notification_preferences()), false, 'default: email off');
SELECT tests.is((SELECT updated_at FROM public.get_notification_preferences()), NULL::timestamptz, 'default: never saved');

-- Save own settings (insert, then update)
SELECT tests.is((SELECT push_enabled FROM public.set_notification_preferences(false, true)), false, 'u1 turns push off');
SELECT tests.is((SELECT email_enabled FROM public.get_notification_preferences()), true, 'and email on');
SELECT tests.lives($$SELECT * FROM public.set_notification_preferences(false, true)$$, 'saving again updates the same row');
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.notification_preferences'), 1::bigint,
    'u1 sees exactly their own row');
SELECT tests.throws($$SELECT * FROM public.set_notification_preferences(NULL, true)$$, 'DC422', 'NULL is rejected');
SELECT tests.throws($$INSERT INTO public.notification_preferences (user_id) VALUES (auth.uid())$$,
    '42501', 'no direct writes');
RESET ROLE;

-- Another user cannot see u1's row
SELECT tests.login('u2');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.notification_preferences'), 0::bigint,
    'u2 cannot read u1''s preferences');
SELECT tests.is((SELECT push_enabled FROM public.get_notification_preferences()), true, 'u2 still has the defaults');
RESET ROLE;

-- u3 turns both push and email off
SELECT tests.login('u3');
SET LOCAL ROLE authenticated;
SELECT tests.lives($$SELECT * FROM public.set_notification_preferences(false, false)$$, 'u3 turns push and email off');
RESET ROLE;

-- The automation identity has no preferences of its own
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT * FROM public.set_notification_preferences(true, true)$$, 'DC403',
    'automation cannot save preferences');

-- write_notification applies the recipient's settings
SELECT tests.remember('n1', public.create_notification(tests.fx('u1'), NULL, 'Approval needed', 'Run x', ARRAY['in_app', 'push']));
SELECT tests.remember('n2', public.create_notification(tests.fx('u2'), NULL, 'Approval needed', 'Run x', ARRAY['in_app', 'push']));
-- Email requested by the caller, but the recipient has email off (u2 defaults; u3 saved off)
SELECT tests.remember('n3', public.create_notification(tests.fx('u2'), NULL, 'Report', 'Run x', ARRAY['in_app', 'email']));
SELECT tests.remember('n4', public.create_notification(tests.fx('u3'), NULL, 'Report', 'Run x', ARRAY['push', 'email']));
SELECT tests.lives($$SELECT public.create_notification(NULL, NULL, 'Team', 'Broadcast', ARRAY['slack'])$$,
    'team broadcasts still work');
RESET ROLE;

SELECT tests.is((SELECT string_agg(channel, ',' ORDER BY channel) FROM public.notification_deliveries WHERE notification_id = tests.fx('n1')),
    'email', 'u1 (push off, email on): email delivery instead of push');
SELECT tests.is((SELECT status FROM public.notifications WHERE id = tests.fx('n1')), 'sent',
    'u1 still gets the in-app inbox row');
SELECT tests.is((SELECT string_agg(channel, ',' ORDER BY channel) FROM public.notification_deliveries WHERE notification_id = tests.fx('n2')),
    'push', 'u2 (defaults): push only, as before');
SELECT tests.is((SELECT count(*) FROM public.notification_deliveries WHERE notification_id = tests.fx('n3')),
    0::bigint, 'u2 (email off): a requested email delivery is removed');
SELECT tests.is((SELECT status FROM public.notifications WHERE id = tests.fx('n3')), 'sent',
    'u2 still gets the in-app inbox row');
SELECT tests.is((SELECT count(*) FROM public.notification_deliveries WHERE notification_id = tests.fx('n4')),
    0::bigint, 'u3 (push and email off): no push and no email delivery');
SELECT tests.is((SELECT status FROM public.notifications WHERE id = tests.fx('n4')), 'sent',
    'u3: the inbox row is still written, not left pending');

-- Deleting the profile removes the preferences
DELETE FROM auth.users WHERE id = tests.fx('u1');
SELECT tests.is(tests.scalar(format('SELECT count(*) FROM public.notification_preferences WHERE user_id = %L', tests.fx('u1'))),
    0::bigint, 'preferences are deleted with the user');

ROLLBACK;
