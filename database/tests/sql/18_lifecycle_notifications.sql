-- 18: Notifications across the incident lifecycle (migration 20261118000300).
--     Admins and operators are notified (in_app + push, preferences apply);
--     the person who acted is skipped; repeats and 'pending' send nothing.
BEGIN;

SELECT tests.remember('bot', tests.create_user('t18.bot@example.test', 'automation'));
SELECT tests.remember('op',  tests.create_user('t18.op@example.test', 'operator'));
SELECT tests.remember('op2', tests.create_user('t18.op2@example.test', 'operator'));
SELECT tests.remember('u1',  tests.create_user('t18.u1@example.test', 'user'));
SELECT tests.remember('adm', 'a0000000-0000-4000-8000-000000000001');

-- op2 has push switched off (S27).
INSERT INTO public.notification_preferences (user_id, push_enabled, email_enabled)
VALUES (tests.fx('op2'), false, false);

-- Everyone who should hear about the incident lifecycle.
CREATE TEMP VIEW responders AS
    SELECT id FROM public.profiles WHERE role IN ('admin', 'operator');
SELECT tests.ok((SELECT count(*) FROM responders) >= 4, 'fixture: at least 4 admins/operators');

-- The helper is internal.
SELECT tests.ok(NOT has_function_privilege('authenticated', 'public.notify_responders(uuid[], uuid, text, text)', 'EXECUTE'),
    'notify_responders is not callable by clients');
SELECT tests.ok(NOT has_function_privilege('anon', 'public.notify_responders(uuid[], uuid, text, text)', 'EXECUTE'),
    'notify_responders is not callable by anon');

-- 1. New incident ---------------------------------------------------------------------
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT set_config('fx.c1', public.create_incident_from_alert('fp-t18-a', 'checkout error rate high',
    'Error rate above 5 %', 'high', 'checkout')::text, true);
SELECT tests.remember('inc1', (current_setting('fx.c1')::jsonb ->> 'incident_id')::uuid);
SELECT public.create_incident_from_alert('fp-t18-a', 'checkout error rate high', NULL, 'high', 'checkout');
RESET ROLE;

SELECT tests.is(
    (SELECT count(*) FROM public.notifications
      WHERE title = 'New incident: checkout error rate high' AND incident_id = tests.fx('inc1')),
    (SELECT count(*) FROM responders),
    'new incident: one notification per admin/operator, none for the repeated alert');
SELECT tests.is(
    (SELECT count(*) FROM public.notifications n
      WHERE n.title = 'New incident: checkout error rate high' AND n.user_id NOT IN (SELECT id FROM responders)),
    0::bigint, 'new incident: users and the automation identity are not notified');
SELECT tests.is(
    (SELECT message FROM public.notifications
      WHERE title = 'New incident: checkout error rate high' AND user_id = tests.fx('op')),
    'High severity on checkout. The investigation has started.', 'new incident: message text');
SELECT tests.is(
    (SELECT count(*) FROM public.notifications n JOIN public.notification_deliveries d ON d.notification_id = n.id
      WHERE n.title = 'New incident: checkout error rate high' AND d.channel = 'push'),
    (SELECT count(*) FROM responders) - 1,
    'new incident: a push delivery for everyone except op2 (push off)');
SELECT tests.is(
    (SELECT count(*) FROM public.notifications n
      WHERE n.title = 'New incident: checkout error rate high' AND n.user_id = tests.fx('op2')
        AND NOT EXISTS (SELECT 1 FROM public.notification_deliveries d WHERE d.notification_id = n.id)),
    1::bigint, 'new incident: op2 still gets the in-app notification');

-- Long titles are trimmed to the 200-character limit.
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.lives(format($$SELECT public.create_incident_from_alert('fp-t18-long', %L, NULL, 'low', 'svc')$$,
    repeat('x', 300)), 'new incident: a 300-character alert title does not break the notification');
RESET ROLE;

-- 2. Remediation finished --------------------------------------------------------------
-- op requests two runs; the admin approves; n8n (bot) starts both.
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT set_config('fx.r1', public.request_playbook_run(tests.fx('inc1'),
    'e0000000-0000-4000-8000-000000000001', 't18-key-0001', '{"target": "checkout"}')::text, true);
SELECT set_config('fx.r2', public.request_playbook_run(tests.fx('inc1'),
    'e0000000-0000-4000-8000-000000000002', 't18-key-0002', '{"target": "checkout"}')::text, true);
RESET ROLE;
SELECT tests.remember('run1', (current_setting('fx.r1')::jsonb ->> 'run_id')::uuid);
SELECT tests.remember('appr1', (current_setting('fx.r1')::jsonb ->> 'approval_id')::uuid);
SELECT tests.remember('run2', (current_setting('fx.r2')::jsonb ->> 'run_id')::uuid);
SELECT tests.remember('appr2', (current_setting('fx.r2')::jsonb ->> 'approval_id')::uuid);

SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
SELECT public.decide_approval(tests.fx('appr1'), 'approved', 'ok');
SELECT public.decide_approval(tests.fx('appr2'), 'approved', 'ok');
RESET ROLE;

SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT public.start_playbook_run(tests.fx('run1'), 'n8n-18-001');
SELECT public.start_playbook_run(tests.fx('run2'), 'n8n-18-002');
-- run1 finishes through n8n.
SELECT public.complete_playbook_run(tests.fx('run1'), 'success', '{}', 'n8n-18-001');
RESET ROLE;

SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE user_id = tests.fx('op') AND title = 'Remediation success'),
    1::bigint, 'remediation: the requester keeps the existing personal message');
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE title = 'Remediation succeeded'),
    (SELECT count(*) FROM responders) - 1,
    'remediation succeeded: every admin/operator except the requester');
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE title = 'Remediation succeeded' AND user_id = tests.fx('op')),
    0::bigint, 'remediation succeeded: the requester is not notified twice');
SELECT tests.is(
    (SELECT message FROM public.notifications WHERE title = 'Remediation succeeded' AND user_id = tests.fx('adm')),
    'The remediation on "checkout error rate high" finished: success.', 'remediation succeeded: message text');

-- run2 is completed manually by op2 (failed).
SELECT tests.login('op2');
SET LOCAL ROLE authenticated;
SELECT public.complete_playbook_run(tests.fx('run2'), 'failed', '{}', NULL, 'n8n was down, closed by hand');
RESET ROLE;

-- The requester's personal message for a failed run has the same title
-- ('Remediation failed'), so the broadcast is told apart by its message.
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE title = 'Remediation failed'
      AND message LIKE 'The remediation on %'),
    (SELECT count(*) FROM responders) - 2,
    'remediation failed (manual): skips the requester and the person who completed it');
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE title = 'Remediation failed'
      AND message LIKE 'The remediation on %' AND user_id IN (tests.fx('op'), tests.fx('op2'))),
    0::bigint, 'remediation failed (manual): op and op2 get no broadcast');
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE user_id = tests.fx('op') AND title = 'Remediation failed'),
    1::bigint, 'remediation failed (manual): the requester gets exactly one message (the personal one)');

-- 3. Recovery check finished -----------------------------------------------------------
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT public.record_recovery_check(tests.fx('inc1'), tests.fx('run1'), 'pending', 'error_rate', '{}');
RESET ROLE;
SELECT tests.is(
    (SELECT count(*) FROM public.notifications
      WHERE incident_id = tests.fx('inc1') AND title IN ('Recovered', 'Not recovered')),
    0::bigint, 'recovery: a pending check sends nothing');

SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT public.record_recovery_check(tests.fx('inc1'), tests.fx('run1'), 'unhealthy', 'error_rate', '{}');
SELECT public.record_recovery_check(tests.fx('inc1'), tests.fx('run1'), 'healthy', 'error_rate', '{}');
RESET ROLE;
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE incident_id = tests.fx('inc1') AND title = 'Not recovered'),
    (SELECT count(*) FROM responders), 'recovery: not recovered goes to every admin/operator');
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE incident_id = tests.fx('inc1') AND title = 'Recovered'),
    (SELECT count(*) FROM responders), 'recovery: recovered goes to every admin/operator');
SELECT tests.is(
    (SELECT message FROM public.notifications
      WHERE incident_id = tests.fx('inc1') AND title = 'Recovered' AND user_id = tests.fx('op')),
    'Recovery check on "checkout error rate high": healthy.', 'recovery: message text');

-- A manual recovery check by an operator skips that operator.
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT public.record_recovery_check(tests.fx('inc1'), NULL, 'failed', 'manual', '{}');
RESET ROLE;
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE incident_id = tests.fx('inc1') AND title = 'Not recovered'),
    (SELECT count(*) FROM responders) * 2 - 1, 'recovery: the operator who recorded the check is skipped');

-- 4a. Postmortem ready -----------------------------------------------------------------
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT public.save_postmortem(tests.fx('inc1'), 'PM summary', 'RC', 'Impact', '[]', NULL, '[]', '{"title": "PM"}');
SELECT public.save_postmortem(tests.fx('inc1'), 'PM summary v2', 'RC', 'Impact', '[]', NULL, '[]', '{"title": "PM v2"}');
RESET ROLE;
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE incident_id = tests.fx('inc1') AND title = 'Postmortem ready'),
    (SELECT count(*) FROM responders), 'postmortem ready: once per admin/operator, not again on a re-run');
SELECT tests.is(
    (SELECT message FROM public.notifications
      WHERE incident_id = tests.fx('inc1') AND title = 'Postmortem ready' AND user_id = tests.fx('adm')),
    'The postmortem for "checkout error rate high" is ready to review.', 'postmortem ready: message text');

-- 4b. Incident resolved ----------------------------------------------------------------
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
UPDATE public.incidents SET status = 'resolved' WHERE id = tests.fx('inc1');
RESET ROLE;
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE incident_id = tests.fx('inc1') AND title = 'Incident resolved'),
    (SELECT count(*) FROM responders) - 1, 'incident resolved: every admin/operator except the one who resolved it');
SELECT tests.is(
    (SELECT count(*) FROM public.notifications
      WHERE incident_id = tests.fx('inc1') AND title = 'Incident resolved' AND user_id = tests.fx('op')),
    0::bigint, 'incident resolved: the person who resolved it is skipped');
SELECT tests.is(
    (SELECT message FROM public.notifications
      WHERE incident_id = tests.fx('inc1') AND title = 'Incident resolved' AND user_id = tests.fx('adm')),
    '"checkout error rate high" was resolved.', 'incident resolved: message text');

-- Other status changes, and changes without a signed-in user (seed scripts,
-- SQL maintenance), send nothing.
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
UPDATE public.incidents SET status = 'closed' WHERE id = tests.fx('inc1');
RESET ROLE;
SELECT tests.clear_claims();
UPDATE public.incidents SET status = 'resolved'
 WHERE id = (SELECT id FROM public.incidents WHERE alert_fingerprint = 'fp-t18-long');
SELECT tests.is(
    (SELECT count(*) FROM public.notifications WHERE title = 'Incident resolved'),
    (SELECT count(*) FROM responders) - 1, 'incident resolved: no notification for closed or for SQL without a user');

ROLLBACK;
