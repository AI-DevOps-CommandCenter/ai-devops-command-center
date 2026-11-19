-- 19: Local releases in deployments (migration 20261118000400).
--     record_deployment / list_recent_deployments are automation-only.
BEGIN;

SELECT tests.remember('bot', tests.create_user('t19.bot@example.test', 'automation'));
SELECT tests.remember('op',  tests.create_user('t19.op@example.test', 'operator'));

-- Clients have no direct access; humans cannot call the functions.
SELECT tests.ok(NOT has_function_privilege('anon', 'public.record_deployment(text, text, text, text)', 'EXECUTE'),
    'anon cannot record a deployment');
SELECT tests.ok(NOT has_function_privilege('anon', 'public.list_recent_deployments(text, timestamptz, timestamptz)', 'EXECUTE'),
    'anon cannot list deployments');
SELECT tests.ok(NOT has_table_privilege('authenticated', 'public.deployments', 'SELECT'),
    'authenticated has no direct SELECT on deployments');

SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.record_deployment('sample-app', 'v2')$$, 'DC403',
    'an operator cannot record a deployment');
SELECT tests.throws($$SELECT * FROM public.list_recent_deployments('sample-app', now() - interval '1 hour', now())$$,
    'DC403', 'an operator cannot list deployments');
RESET ROLE;

-- Input checks
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.record_deployment('', 'v2')$$, 'DC422', 'empty service_name is rejected');
SELECT tests.throws($$SELECT public.record_deployment('sample app', 'v2')$$, 'DC422', 'service_name with a space is rejected');
SELECT tests.throws($$SELECT public.record_deployment('sample-app', NULL)$$, 'DC422', 'a version is required');
SELECT tests.throws($$SELECT public.record_deployment('sample-app', 'v2; drop')$$, 'DC422', 'a version with odd characters is rejected');
SELECT tests.throws($$SELECT public.record_deployment('sample-app', 'v2', 'running')$$, 'DC422', 'status must be success or failed');
SELECT tests.throws($$SELECT public.record_deployment('sample-app', 'v2', 'success', 'Local CI')$$, 'DC422', 'provider format is checked');
SELECT tests.throws($$SELECT * FROM public.list_recent_deployments('sample-app', now(), now() - interval '1 hour')$$,
    'DC422', 'since after until is rejected');
SELECT tests.throws($$SELECT * FROM public.list_recent_deployments('sample-app', now() - interval '8 days', now())$$,
    'DC422', 'a window over 7 days is rejected');

-- Record and read back
SELECT tests.remember('d1', public.record_deployment('sample-app', 'v2'));
SELECT tests.remember('d2', public.record_deployment('sample-app', 'v1', 'success', 'local'));
SELECT public.record_deployment('other-app', 'v9');
RESET ROLE;

SELECT tests.is(
    (SELECT count(*) FROM public.deployments
      WHERE id = tests.fx('d1') AND service_name = 'sample-app' AND version = 'v2'
        AND provider = 'local' AND status = 'success' AND completed_at IS NOT NULL AND started_at IS NOT NULL),
    1::bigint, 'record_deployment stores service, version, provider, status and time');
SELECT tests.is(
    (SELECT count(*) FROM public.audit_logs WHERE action = 'DEPLOYMENT_RECORDED' AND entity_id = tests.fx('d1')),
    1::bigint, 'record_deployment writes an audit entry');

-- Move d2 out of the window to check the time filter.
UPDATE public.deployments SET completed_at = now() - interval '3 hours' WHERE id = tests.fx('d2');

SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.is(
    (SELECT count(*) FROM public.list_recent_deployments('sample-app', now() - interval '1 hour', now() + interval '1 minute')),
    1::bigint, 'list_recent_deployments returns only releases of that service in the window');
SELECT tests.is(
    (SELECT version FROM public.list_recent_deployments('sample-app', now() - interval '1 hour', now() + interval '1 minute')),
    'v2', 'list_recent_deployments returns the version');
SELECT tests.is(
    (SELECT count(*) FROM public.list_recent_deployments('sample-app', now() - interval '4 hours', now() + interval '1 minute')),
    2::bigint, 'a wider window includes the older release');
RESET ROLE;

-- At most 20 rows, newest first.
INSERT INTO public.deployments (service_name, version, provider, status, started_at, completed_at)
SELECT 'bulk-app', 'v' || g, 'local', 'success', now() - g * interval '1 minute', now() - g * interval '1 minute'
FROM generate_series(1, 25) g;
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.is(
    (SELECT count(*) FROM public.list_recent_deployments('bulk-app', now() - interval '1 day', now())),
    20::bigint, 'list_recent_deployments returns at most 20 rows');
SELECT tests.is(
    (SELECT version FROM public.list_recent_deployments('bulk-app', now() - interval '1 day', now()) LIMIT 1),
    'v1', 'list_recent_deployments returns the newest first');
RESET ROLE;

-- Column checks also apply to direct writes.
SELECT tests.throws($$INSERT INTO public.deployments (service_name, status) VALUES ('bad name', 'success')$$,
    '23514', 'deployments_service_name_check rejects a bad service name');

ROLLBACK;
