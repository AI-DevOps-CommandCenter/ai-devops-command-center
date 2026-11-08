-- 12: Notifications (A6, migration 000600).
BEGIN;

SELECT tests.remember('u1',  tests.create_user('t12.u1@example.test', 'user'));
SELECT tests.remember('u2',  tests.create_user('t12.u2@example.test', 'user'));
SELECT tests.remember('op',  tests.create_user('t12.op@example.test', 'operator'));
SELECT tests.remember('bot', tests.create_user('t12.bot@example.test', 'automation'));
SELECT tests.remember('adm', 'a0000000-0000-4000-8000-000000000001');

-- Device tokens: the user id always comes from the JWT.
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.lives($$SELECT public.register_device_token('fcm-token-operator-0001', 'android')$$,
    'an operator registers a device');
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.device_tokens'), 1::bigint, 'and sees their own device');
SELECT tests.throws($$SELECT public.register_device_token('fcm-token-operator-0002', 'windows')$$,
    'DC422', 'unknown platform rejected');
RESET ROLE;

SELECT tests.login('u2');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.device_tokens'), 0::bigint, 'users cannot see other devices');
SELECT tests.is(public.unregister_device_token('fcm-token-operator-0001'), false,
    'users cannot remove another user''s device');
SELECT tests.throws($$INSERT INTO public.notifications (user_id, title, message) VALUES (auth.uid(), 't', 'm')$$,
    '42501', 'clients cannot write notifications directly');
SELECT tests.throws(format($$SELECT public.create_notification(%L, NULL, 'Hi', 'spam')$$, tests.fx('u1')),
    'DC403', 'humans cannot notify other users');
RESET ROLE;

-- A run request notifies every approver except the requester (in_app + push).
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
INSERT INTO public.incidents (id, title, service_name, created_by)
VALUES ('c1200000-0000-4000-8000-000000000001', 'u1 incident', 'svc', tests.fx('u1'));
SELECT public.request_playbook_run('c1200000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001');
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.notifications'), 0::bigint,
    'the requester gets no approval notification');
RESET ROLE;

SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar($$SELECT count(*) FROM public.notifications WHERE title = 'Approval needed'
                               AND channel = 'in_app' AND status = 'sent'$$), 1::bigint,
    'the operator has the approval request in their inbox');
SELECT tests.remember('n_op', (SELECT id FROM public.notifications LIMIT 1));
SELECT tests.lives(format($$SELECT public.mark_notification_read(%L)$$, tests.fx('n_op')),
    'the operator marks it read');
SELECT tests.is((SELECT status FROM public.notifications WHERE id = tests.fx('n_op')), 'read', 'status is read');
RESET ROLE;
SELECT tests.login('u2');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.mark_notification_read(%L)$$, tests.fx('n_op')),
    'DC404', 'users cannot touch someone else''s notification');
RESET ROLE;

-- Backend notification module (automation identity)
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.lives($$SELECT public.create_notification(NULL, 'c1200000-0000-4000-8000-000000000001',
                     'Incident update', 'Restart requested', ARRAY['slack', 'discord'])$$,
    'team broadcast to Slack and Discord (A6)');
SELECT tests.throws($$SELECT public.create_notification(NULL, NULL, 'x', 'y', ARRAY['in_app'])$$,
    'DC422', 'in_app needs a recipient');
SELECT tests.throws(format($$SELECT public.create_notification(%L, NULL, 'x', 'y', ARRAY['telegram'])$$, tests.fx('u1')),
    'DC422', 'unknown channels rejected');
SELECT tests.lives(format($$SELECT public.create_notification(%L, NULL, 'Weekly report', 'Ready', ARRAY['in_app', 'email'])$$,
                          tests.fx('u1')),
    'automation sends a user an in-app + email notification');

-- 3 approvers (seed admin, seed operator, op) x push + slack + discord + email = 6.
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.claim_notification_deliveries(50)'), 6::bigint,
    'the backend claims all pending deliveries');
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.claim_notification_deliveries(50)'), 0::bigint,
    'claimed deliveries are not handed out again within 2 minutes');
RESET ROLE;

SELECT tests.clear_claims();
UPDATE public.notification_deliveries SET attempted_at = now() - interval '5 minutes';
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.is(
    (SELECT device_tokens FROM public.claim_notification_deliveries(50) WHERE user_id = tests.fx('op') AND channel = 'push'),
    ARRAY['fcm-token-operator-0001'], 'push deliveries include the recipient''s device tokens');
RESET ROLE;
SELECT tests.is((SELECT attempt_count FROM public.notification_deliveries WHERE channel = 'email'), 2,
    'each claim counts as an attempt');

SELECT tests.clear_claims();
SELECT tests.remember('d_email', (SELECT id FROM public.notification_deliveries WHERE channel = 'email'));
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.lives(format($$SELECT public.record_notification_delivery(%L, 'failed', NULL, 'SMTP 550')$$, tests.fx('d_email')),
    'the backend records a failed delivery');
SELECT tests.throws(format($$SELECT public.record_notification_delivery(%L, 'sent')$$, tests.fx('d_email')),
    'DC409', 'a failed delivery is final');
SELECT tests.throws(format($$SELECT public.record_notification_delivery(%L, 'bounced')$$, tests.fx('d_email')),
    'DC422', 'unknown delivery status rejected');
RESET ROLE;

SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT * FROM public.claim_notification_deliveries(10)$$,
    'DC403', 'humans cannot claim deliveries');
SELECT tests.throws($$SELECT 1 FROM public.notification_deliveries$$,
    '42501', 'clients cannot read delivery records directly');
RESET ROLE;

ROLLBACK;
