-- 03: CHECK, UNIQUE and FOREIGN KEY behaviour of the baseline (run as the
--     table owner, so RLS does not interfere).
BEGIN;

SELECT tests.remember('incident', 'c0000000-0000-4000-8000-000000000001');
SELECT tests.remember('playbook', 'e0000000-0000-4000-8000-000000000001');
SELECT tests.remember('admin',    'a0000000-0000-4000-8000-000000000001');

-- CHECK constraints (allowed value sets)
SELECT tests.throws($$INSERT INTO public.incidents (title, status) VALUES ('x', 'reopened')$$,
    '23514', 'incidents.status rejects unknown values');
SELECT tests.throws($$INSERT INTO public.incidents (title, severity) VALUES ('x', 'urgent')$$,
    '23514', 'incidents.severity rejects unknown values');
SELECT tests.throws($$UPDATE public.profiles SET role = 'superuser' WHERE id = tests.fx('admin')$$,
    '23514', 'profiles.role allows only user/admin/operator');
SELECT tests.lives($$UPDATE public.profiles SET role = 'automation' WHERE id = 'a0000000-0000-4000-8000-000000000002'$$,
    'profiles.role accepts automation (A5; the owner may set it, see suite 09)');
UPDATE public.profiles SET role = 'operator' WHERE id = 'a0000000-0000-4000-8000-000000000002';
SELECT tests.throws($$INSERT INTO public.playbooks (name, action_type) VALUES ('t1', 'restart_service')$$,
    '23514', 'playbooks.action_type stores restart/rollback/scale/circuit_breaker (not restart_service etc.)');
SELECT tests.lives($$INSERT INTO public.playbooks (name, action_type) VALUES ('t2', 'circuit_breaker')$$,
    'playbooks.action_type accepts circuit_breaker');
SELECT tests.throws(format($$INSERT INTO public.playbook_runs (playbook_id, incident_id, status)
                             VALUES (%L, %L, 'queued')$$, tests.fx('playbook'), tests.fx('incident')),
    '23514', 'playbook_runs.status rejects unknown values');
SELECT tests.throws(format($$INSERT INTO public.approvals (incident_id, status) VALUES (%L, 'expired')$$,
                           tests.fx('incident')),
    '23514', 'approvals.status has no expired value (A3-Q4: no expiry for now)');
SELECT tests.lives($$INSERT INTO public.approvals (incident_id, status)
                     VALUES ('c0000000-0000-4000-8000-000000000002', 'cancelled')$$,
    'approvals.status accepts cancelled (A3)');
SELECT tests.throws(format($$INSERT INTO public.ai_analyses (incident_id, confidence) VALUES (%L, 1.5)$$,
                           tests.fx('incident')),
    '23514', 'ai_analyses.confidence must be between 0 and 1');
SELECT tests.throws(format($$INSERT INTO public.ai_analyses (incident_id, recommended_action) VALUES (%L, 'reboot')$$,
                           tests.fx('incident')),
    '23514', 'ai_analyses.recommended_action uses the playbook action set');
SELECT tests.throws(format($$INSERT INTO public.device_tokens (user_id, device_token, platform)
                             VALUES (%L, 'tok-x', 'windows')$$, tests.fx('admin')),
    '23514', 'device_tokens.platform allows android/ios/web');
SELECT tests.lives(format($$INSERT INTO public.notifications (user_id, title, message, channel)
                            VALUES (%L, 't', 'm', 'slack')$$, tests.fx('admin')),
    'notifications.channel accepts slack (A6 / R4)');
SELECT tests.throws(format($$INSERT INTO public.notifications (user_id, title, message, channel)
                             VALUES (%L, 't', 'm', 'telegram')$$, tests.fx('admin')),
    '23514', 'notifications.channel no longer accepts telegram (A6)');
SELECT tests.lives(format($$INSERT INTO public.recovery_checks (incident_id, status) VALUES (%L, 'unhealthy')$$,
                          tests.fx('incident')),
    'recovery_checks accepts an unhealthy (failed) result');
SELECT tests.lives(format($$INSERT INTO public.remediation_executions (incident_id, status) VALUES (%L, 'failed')$$,
                          tests.fx('incident')),
    'remediation_executions accepts a failed result');

-- UNIQUE constraints
SELECT tests.throws($$INSERT INTO public.playbooks (name, action_type) VALUES ('Synthetic Restart', 'restart')$$,
    '23505', 'playbooks.name is unique');
SELECT tests.throws(format($$INSERT INTO public.postmortems (incident_id, summary) VALUES (%L, 'dup')$$,
                           tests.fx('incident')),
    '23505', 'one postmortem per incident');
SELECT tests.throws($$INSERT INTO auth.users (email) VALUES ('synthetic.admin@example.test')$$,
    '23505', 'profiles.email is unique (enforced through the auth trigger)');
SELECT tests.lives(format($$INSERT INTO public.device_tokens (user_id, device_token, platform)
                            VALUES (%L, 'tok-1', 'android')$$, tests.fx('admin')),
    'device token registered');
SELECT tests.throws(format($$INSERT INTO public.device_tokens (user_id, device_token, platform)
                             VALUES (%L, 'tok-1', 'ios')$$, tests.fx('admin')),
    '23505', 'device_tokens.device_token is unique');

-- FOREIGN KEYS
SELECT tests.throws(format($$INSERT INTO public.playbook_runs (playbook_id, incident_id)
                             VALUES (gen_random_uuid(), %L)$$, tests.fx('incident')),
    '23503', 'playbook_runs.playbook_id must reference a playbook');
SELECT tests.throws(format($$DELETE FROM public.playbooks WHERE id = %L$$,
                           'e0000000-0000-4000-8000-000000000001'),
    '23001', 'a playbook with runs cannot be deleted (RESTRICT)');

-- Current CASCADE behaviour: deleting an incident removes its children.
SELECT tests.is(
    (SELECT count(*) FROM public.investigations WHERE incident_id = tests.fx('incident')) > 0,
    true, 'incident has investigations before delete');
DELETE FROM public.incidents WHERE id = tests.fx('incident');
SELECT tests.is(
    (SELECT count(*) FROM public.investigations WHERE incident_id = tests.fx('incident'))
      + (SELECT count(*) FROM public.approvals WHERE incident_id = tests.fx('incident'))
      + (SELECT count(*) FROM public.postmortems WHERE incident_id = tests.fx('incident')),
    0::bigint, 'CASCADE: deleting an incident deletes its history (A8-Q5 pending; clients have no DELETE grant)');

ROLLBACK;

BEGIN;
-- A7-Q3: deleting a user keeps audit rows AND their actor id (no FK).
SELECT tests.remember('operator', 'a0000000-0000-4000-8000-000000000002');
SELECT tests.ok(
    (SELECT count(*) FROM public.audit_logs WHERE actor_id = tests.fx('operator')) > 0,
    'operator has audit entries');
DELETE FROM auth.users WHERE id = tests.fx('operator');
SELECT tests.is(
    (SELECT count(*) FROM public.profiles WHERE id = tests.fx('operator')),
    0::bigint, 'deleting the auth user cascades to the profile');
SELECT tests.is(
    (SELECT count(*) FROM public.audit_logs WHERE actor_id = tests.fx('operator')),
    12::bigint, 'audit rows survive unchanged, actor id kept (A7-Q3)');
ROLLBACK;
