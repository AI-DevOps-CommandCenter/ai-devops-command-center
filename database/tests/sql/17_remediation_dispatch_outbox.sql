-- 17: Dispatch outbox for approved runs (migration 20261118000200).
BEGIN;

SELECT tests.remember('bot', tests.create_user('t17.bot@example.test', 'automation'));
SELECT tests.remember('op',  tests.create_user('t17.op@example.test', 'operator'));

-- Fixture runs on the seeded incident, one per seeded playbook (the unique
-- index allows one active run per incident and playbook). Written directly
-- (as the test owner) to set the approval time.
INSERT INTO public.playbook_runs (id, playbook_id, incident_id, status, approval_required, request_payload, requested_at, approved_at)
VALUES
  ('d1700000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001',
   'approved', true, '{"service_name": "svc-a"}', now() - interval '10 minutes', now() - interval '5 minutes'),
  ('d1700000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001',
   'approved', true, '{"service_name": "svc-b"}', now() - interval '1 minute', now() - interval '5 seconds'),
  ('d1700000-0000-4000-8000-000000000003', 'e0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001',
   'running', true, '{}', now() - interval '10 minutes', now() - interval '5 minutes');

SELECT tests.is((SELECT dispatch_attempts FROM public.playbook_runs WHERE id = 'd1700000-0000-4000-8000-000000000001'), 0,
    'new columns: dispatch_attempts defaults to 0');
SELECT tests.throws($$UPDATE public.playbook_runs SET dispatch_attempts = -1 WHERE id = 'd1700000-0000-4000-8000-000000000001'$$,
    '23514', 'dispatch_attempts cannot be negative');

-- Humans cannot claim runs
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT * FROM public.claim_runs_for_dispatch()$$, 'DC403', 'an operator cannot claim runs for dispatch');
RESET ROLE;
SELECT tests.ok(NOT has_function_privilege('anon', 'public.claim_runs_for_dispatch(integer, integer, integer, integer)', 'EXECUTE'),
    'anon cannot call the claim function');

-- The automation identity claims due runs only
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT * FROM public.claim_runs_for_dispatch(0)$$, 'DC422', 'limit 0 is rejected');
SELECT tests.throws($$SELECT * FROM public.claim_runs_for_dispatch(10, 30, 1)$$, 'DC422', 'a retry interval under 5 s is rejected');

CREATE TEMP TABLE first_claim ON COMMIT DROP AS SELECT * FROM public.claim_runs_for_dispatch(10, 30, 30, 3);
RESET ROLE;
SELECT tests.is((SELECT string_agg(run_id::text, ',') FROM first_claim), 'd1700000-0000-4000-8000-000000000001',
    'only the approved run past the 30 s grace is claimed (not the fresh one, not the running one)');
SELECT tests.is((SELECT action_type FROM first_claim), 'restart', 'the action comes from the playbook');
SELECT tests.is((SELECT request_payload ->> 'service_name' FROM first_claim), 'svc-a', 'with the run''s request_payload');
SELECT tests.is((SELECT dispatch_attempts FROM first_claim), 1, 'the attempt is counted');
SELECT tests.ok((SELECT last_dispatch_at > now() - interval '1 minute' FROM public.playbook_runs
                 WHERE id = 'd1700000-0000-4000-8000-000000000001'), 'and its time recorded');
SELECT tests.is((SELECT status FROM public.playbook_runs WHERE id = 'd1700000-0000-4000-8000-000000000001'), 'approved',
    'claiming does not change the run status');

-- Not again within the retry interval
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.claim_runs_for_dispatch(10, 30, 30, 3)'), 0::bigint,
    'a claimed run is not handed out again within the retry interval');
RESET ROLE;

-- After the retry interval, again; and never more than p_max_attempts times
UPDATE public.playbook_runs SET last_dispatch_at = now() - interval '1 minute' WHERE id = 'd1700000-0000-4000-8000-000000000001';
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.claim_runs_for_dispatch(10, 30, 30, 3)'), 1::bigint,
    'claimed again after the retry interval');
RESET ROLE;
UPDATE public.playbook_runs SET dispatch_attempts = 3, last_dispatch_at = now() - interval '1 hour'
WHERE id = 'd1700000-0000-4000-8000-000000000001';
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.claim_runs_for_dispatch(10, 30, 30, 3)'), 0::bigint,
    'not claimed after p_max_attempts attempts (stays approved for an operator)');
RESET ROLE;

-- The fresh run becomes due after its grace period
UPDATE public.playbook_runs SET approved_at = now() - interval '2 minutes' WHERE id = 'd1700000-0000-4000-8000-000000000002';
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.is((SELECT string_agg(run_id::text, ',') FROM public.claim_runs_for_dispatch(10, 30, 30, 3)),
    'd1700000-0000-4000-8000-000000000002', 'a run becomes due after the grace period');
RESET ROLE;

-- A started run is never claimed, whatever its attempts
UPDATE public.playbook_runs SET status = 'running' WHERE id = 'd1700000-0000-4000-8000-000000000002';
UPDATE public.playbook_runs SET last_dispatch_at = NULL WHERE id = 'd1700000-0000-4000-8000-000000000002';
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.claim_runs_for_dispatch(10, 0, 30, 3)'), 0::bigint,
    'running runs are not dispatched again');
RESET ROLE;

ROLLBACK;
