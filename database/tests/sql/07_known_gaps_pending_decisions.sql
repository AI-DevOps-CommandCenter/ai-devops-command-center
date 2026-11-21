-- 07: Known gaps from the Phase 19 audit.
--
-- CLOSED gaps are asserted to be blocked now (A2/A3/A4/A5/A7 implemented by
-- migrations 000400-000700, 2026-11-07). OPEN gaps still characterise the
-- current behaviour and pass because nothing blocks them yet; flip them when
-- their decision is implemented (see database/DATABASE_TEAM_HANDOVER.md).
BEGIN;

SELECT tests.remember('u1', tests.create_user('t07.u1@example.test', 'user'));
SELECT tests.remember('op', tests.create_user('t07.op@example.test', 'operator'));

SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
INSERT INTO public.incidents (id, title, service_name, created_by)
VALUES ('c0700000-0000-4000-8000-000000000001', 'u1 incident', 'svc', tests.fx('u1'));

SELECT tests.throws(format($$INSERT INTO public.approvals (incident_id, requested_by, approver_id, status)
                             VALUES ('c0700000-0000-4000-8000-000000000001', %1$L, %1$L, 'approved')$$, tests.fx('u1')),
    '42501', 'GAP-01 CLOSED (A2/A3): a user cannot insert a self-approved approval');

SELECT tests.throws(format($$INSERT INTO public.playbook_runs (playbook_id, incident_id, requested_by, approved_by, status)
                             VALUES ('e0000000-0000-4000-8000-000000000001', 'c0700000-0000-4000-8000-000000000001',
                                     %1$L, %1$L, 'approved')$$, tests.fx('u1')),
    '42501', 'GAP-02 CLOSED (A2/A3): a user cannot insert a pre-approved playbook run');

SELECT tests.throws($$SELECT public.request_playbook_run('c0700000-0000-4000-8000-000000000001',
                                                          'e0000000-0000-4000-8000-000000000004')$$,
    'DC409', 'GAP-03 CLOSED (A3/A4): a run cannot be requested for a disabled playbook');

SELECT tests.lives($$SELECT public.request_playbook_run('c0700000-0000-4000-8000-000000000001',
                                                         'e0000000-0000-4000-8000-000000000002')$$,
    'a first run request succeeds');
SELECT tests.throws($$SELECT public.request_playbook_run('c0700000-0000-4000-8000-000000000001',
                                                          'e0000000-0000-4000-8000-000000000002')$$,
    'DC409', 'GAP-04 CLOSED (A3): no second active run for the same incident and playbook');

SELECT tests.throws($$INSERT INTO public.audit_logs (actor_id, action, details)
                      VALUES (auth.uid(), 'APPROVAL_DECIDED', '{"forged": true}')$$,
    '42501', 'GAP-05 CLOSED (A7): users cannot write audit entries');
RESET ROLE;

SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$INSERT INTO public.remediation_executions (incident_id, status, started_at, completed_at)
                      VALUES ('c0700000-0000-4000-8000-000000000001', 'succeeded', now(), now())$$,
    '42501', 'GAP-06 CLOSED (A2/A3): no remediation can be recorded outside the approval workflow');

SELECT tests.is(tests.affected($$UPDATE public.incidents SET status = 'open'
                                 WHERE id = 'c0000000-0000-4000-8000-000000000003'$$), 1::bigint,
    'GAP-07 OPEN (U11): invalid incident transitions (resolved -> open) are not blocked');
SELECT tests.is(tests.affected($$UPDATE public.incidents SET status = 'resolved'
                                 WHERE id = 'c0700000-0000-4000-8000-000000000001'$$), 1::bigint,
    'GAP-08 OPEN (U11): an incident can be resolved without a healthy recovery check');
RESET ROLE;

-- Owner-level gaps
SELECT tests.clear_claims();
SELECT tests.throws($$UPDATE public.audit_logs SET action = 'rewritten' WHERE details ->> 'sequence' = '1'$$,
    'DC403', 'GAP-09 CLOSED (A7): audit rows are append-only even for the owner');
SELECT tests.throws($$INSERT INTO public.approvals (incident_id, requested_by, approver_id, status)
                      VALUES ('c0000000-0000-4000-8000-000000000002',
                              'a0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002', 'approved')$$,
    '23514', 'GAP-10 CLOSED (A3): approver = requester is rejected by a CHECK, for every writer');

ROLLBACK;
