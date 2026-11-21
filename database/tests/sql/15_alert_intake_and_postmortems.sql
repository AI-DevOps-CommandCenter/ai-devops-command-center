-- 15: Alert intake, AI analysis on investigations and postmortems
--     (migration 20261117000100; backend dependencies BD-1, BD-2, BD-4).
BEGIN;

SELECT tests.remember('u1',  tests.create_user('t15.u1@example.test', 'user'));
SELECT tests.remember('bot', tests.create_user('t15.bot@example.test', 'automation'));

-- Humans cannot create incidents from alerts or save automation postmortems.
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.create_incident_from_alert('fp-t15-a', 'x', NULL, 'high', 'svc')$$,
    'DC403', 'BD-1: a user cannot create an incident from an alert');
SELECT tests.throws($$SELECT public.get_incident_context('c0000000-0000-4000-8000-000000000001')$$,
    'DC403', 'BD-4: a user cannot read the automation context');
SELECT tests.throws($$SELECT public.save_postmortem('c0000000-0000-4000-8000-000000000001', 's', NULL, NULL,
                      '[]', NULL, '[]', NULL)$$,
    'DC403', 'BD-4: a user cannot save an automation postmortem');
RESET ROLE;

SELECT tests.login('bot');
SET LOCAL ROLE authenticated;

-- BD-1: create, then idempotent on the fingerprint.
SELECT set_config('fx.c1', public.create_incident_from_alert('fp-t15-a', 'sample-app high error rate',
    'Error rate above 5 %', 'high', 'sample-app', 'demo', '2026-11-17T08:00:00Z')::text, true);
SELECT tests.remember('inc1', (current_setting('fx.c1')::jsonb ->> 'incident_id')::uuid);
SELECT tests.remember('inv1', (current_setting('fx.c1')::jsonb ->> 'investigation_id')::uuid);
SELECT tests.is(current_setting('fx.c1')::jsonb ->> 'created', 'true', 'BD-1: the first delivery creates an incident');
RESET ROLE;  -- read the tables directly (the automation identity has no table SELECT)
SELECT tests.is(tests.scalar(format($$SELECT count(*) FROM public.incidents WHERE id = %L AND status = 'investigating'
                                     AND source = 'alertmanager' AND service_name = 'sample-app'$$, tests.fx('inc1'))),
    1::bigint, 'BD-1: incident status, source and service are set');
SET LOCAL ROLE authenticated;
RESET ROLE;  -- read the tables directly (the automation identity has no table SELECT)
SELECT tests.is(tests.scalar(format($$SELECT count(*) FROM public.investigations WHERE id = %L AND incident_id = %L
                                     AND status = 'running'$$, tests.fx('inv1'), tests.fx('inc1'))),
    1::bigint, 'BD-1: a running investigation is created for the incident');
SET LOCAL ROLE authenticated;

SELECT set_config('fx.c2', public.create_incident_from_alert('fp-t15-a', 'again', NULL, 'high', 'sample-app')::text, true);
SELECT tests.is(current_setting('fx.c2')::jsonb ->> 'created', 'false', 'BD-1: a repeated delivery does not create a second incident');
SELECT tests.is((current_setting('fx.c2')::jsonb ->> 'incident_id')::uuid, tests.fx('inc1'),
    'BD-1: a repeated delivery returns the same incident');
SELECT tests.is((current_setting('fx.c2')::jsonb ->> 'investigation_id')::uuid, tests.fx('inv1'),
    'BD-1: a repeated delivery returns the same investigation');

SELECT tests.throws($$SELECT public.create_incident_from_alert('fp-t15-b', 'x', NULL, 'urgent', 'svc')$$,
    '23514', 'BD-1: severity outside incidents_severity_check is rejected');
SELECT tests.throws($$SELECT public.create_incident_from_alert('', 'x', NULL, 'high', 'svc')$$,
    'DC422', 'BD-1: an empty fingerprint is rejected');

-- BD-2: the analysis completes the investigation.
SELECT tests.lives(format($$SELECT public.record_ai_analysis(%L, %L, 'synthetic-model', 'Summary 15',
                            'Root cause 15', 'high', 0.8, '["log: 500 errors"]', 'restart')$$,
                          tests.fx('inc1'), tests.fx('inv1')),
    'BD-2: n8n records the analysis for the investigation');
RESET ROLE;  -- read the tables directly (the automation identity has no table SELECT)
SELECT tests.is(tests.scalar(format($$SELECT count(*) FROM public.investigations WHERE id = %L AND status = 'completed'
                                     AND root_cause = 'Root cause 15' AND ai_model = 'synthetic-model'$$, tests.fx('inv1'))),
    1::bigint, 'BD-2: the investigation is completed with the AI result');
SET LOCAL ROLE authenticated;

-- BD-4: context and postmortem (insert, then update in place).
SELECT tests.is(tests.scalar(format($$SELECT count(*) WHERE public.get_incident_context(%L) -> 'rca' ->> 'root_cause'
                                     = 'Root cause 15'$$, tests.fx('inc1'))),
    1::bigint, 'BD-4: the context contains the latest AI analysis');
SELECT tests.is(tests.scalar(format($$SELECT count(*) WHERE public.get_incident_context(%L) -> 'incident' ->> 'service_name'
                                     = 'sample-app'$$, tests.fx('inc1'))),
    1::bigint, 'BD-4: the context contains the incident');
SELECT tests.throws($$SELECT public.get_incident_context('99999999-0000-4000-8000-000000000001')$$,
    'DC404', 'BD-4: unknown incident -> DC404');

SELECT set_config('fx.pm1', public.save_postmortem(tests.fx('inc1'), 'PM summary', 'RC', 'Impact',
    '[{"time": "08:00", "event": "alert"}]', 'Lesson', '["Add alert"]', '{"title": "PM"}')::text, true);
SELECT set_config('fx.pm2', public.save_postmortem(tests.fx('inc1'), 'PM summary v2', 'RC', 'Impact',
    '[]', NULL, '[]', '{"title": "PM v2"}')::text, true);
SELECT tests.is(current_setting('fx.pm2'), current_setting('fx.pm1'), 'BD-4: a re-run updates the same postmortem');
RESET ROLE;  -- read the tables directly (the automation identity has no table SELECT)
SELECT tests.is(tests.scalar(format($$SELECT count(*) FROM public.postmortems WHERE id = %L AND summary = 'PM summary v2'$$,
                                     current_setting('fx.pm1'))),
    1::bigint, 'BD-4: the postmortem holds the latest draft');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.save_postmortem(%L, 's', NULL, NULL, '{}', NULL, '[]', NULL)$$, tests.fx('inc1')),
    'DC422', 'BD-4: timeline must be an array');
RESET ROLE;

-- A resolved incident no longer blocks a new incident for the same alert.
UPDATE public.incidents SET status = 'resolved', resolved_at = now() WHERE id = tests.fx('inc1');
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT set_config('fx.c3', public.create_incident_from_alert('fp-t15-a', 'fires again', NULL, 'high', 'sample-app')::text, true);
SELECT tests.is(current_setting('fx.c3')::jsonb ->> 'created', 'true',
    'BD-1: the same alert after the incident is resolved creates a new incident');
RESET ROLE;

ROLLBACK;
