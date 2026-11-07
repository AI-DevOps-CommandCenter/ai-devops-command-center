-- 06: Approval and run decision rules enforced by the CURRENT policies.
BEGIN;

SELECT tests.remember('u1',  tests.create_user('t06.u1@example.test', 'user'));
SELECT tests.remember('op',  tests.create_user('t06.op@example.test', 'operator'));
SELECT tests.remember('adm', 'a0000000-0000-4000-8000-000000000001');
SELECT tests.remember('adm2', tests.create_user('t06.adm2@example.test', 'admin'));

-- u1 raises an incident and requests approval.
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
INSERT INTO public.incidents (id, title, service_name, created_by)
VALUES ('c0600000-0000-4000-8000-000000000001', 'u1 incident', 'svc', tests.fx('u1'));
SELECT tests.lives(format($$INSERT INTO public.approvals (id, incident_id, requested_by)
                            VALUES ('f0600000-0000-4000-8000-000000000001', 'c0600000-0000-4000-8000-000000000001', %L)$$,
                          tests.fx('u1')),
    'user requests an approval');
SELECT tests.is(tests.affected(format($$UPDATE public.approvals SET status = 'approved', approver_id = %L
                                        WHERE id = 'f0600000-0000-4000-8000-000000000001'$$, tests.fx('u1'))),
    0::bigint, 'requester cannot approve their own request');
RESET ROLE;

-- Operators cannot decide approvals (admin-only today).
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.affected(format($$UPDATE public.approvals SET status = 'approved', approver_id = %L
                                        WHERE id = 'f0600000-0000-4000-8000-000000000001'$$, tests.fx('op'))),
    0::bigint, 'operator cannot decide approvals (admin only; A3-Q1 pending)');
RESET ROLE;

-- Admin decides, but only as themselves.
SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$UPDATE public.approvals SET status = 'approved', approver_id = %L
                             WHERE id = 'f0600000-0000-4000-8000-000000000001'$$, tests.fx('op')),
    '42501', 'admin cannot record someone else as the approver');
SELECT tests.is(tests.affected(format($$UPDATE public.approvals SET status = 'approved', approver_id = %L,
                                        decided_at = now() WHERE id = 'f0600000-0000-4000-8000-000000000001'$$,
                                      tests.fx('adm'))),
    1::bigint, 'admin approves another user''s request');
SELECT tests.is(tests.affected(format($$UPDATE public.approvals SET status = 'rejected', approver_id = %L
                                        WHERE id = 'f0600000-0000-4000-8000-000000000001'$$, tests.fx('adm'))),
    0::bigint, 'a decided approval cannot be changed again');

-- The seeded deadlock: the only original admin requested this approval.
SELECT tests.is(tests.affected(format($$UPDATE public.approvals SET status = 'approved', approver_id = %L
                                        WHERE id = 'f1000000-0000-4000-8000-000000000001'$$, tests.fx('adm'))),
    0::bigint, 'the seeded admin cannot approve their own pending request (deadlock case)');
RESET ROLE;
SELECT tests.login('adm2');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.affected(format($$UPDATE public.approvals SET status = 'approved', approver_id = %L
                                        WHERE id = 'f1000000-0000-4000-8000-000000000001'$$, tests.fx('adm2'))),
    1::bigint, 'a second admin could resolve the deadlock (A3-Q2 is a human decision)');
RESET ROLE;

-- Playbook run decisions: approver must differ from requester.
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
INSERT INTO public.playbook_runs (id, playbook_id, incident_id, requested_by)
VALUES ('f0600000-0000-4000-8000-0000000000a1', 'e0000000-0000-4000-8000-000000000001',
        'c0600000-0000-4000-8000-000000000001', tests.fx('op'));
SELECT tests.throws(format($$UPDATE public.playbook_runs SET status = 'approved', approved_by = %L
                             WHERE id = 'f0600000-0000-4000-8000-0000000000a1'$$, tests.fx('op')),
    '42501', 'a manager cannot approve their own playbook run');
RESET ROLE;
SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.affected(format($$UPDATE public.playbook_runs SET status = 'approved', approved_by = %L
                                        WHERE id = 'f0600000-0000-4000-8000-0000000000a1'$$, tests.fx('adm'))),
    1::bigint, 'another manager can approve the run');
RESET ROLE;

-- Users cannot change runs at all.
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.affected($$UPDATE public.playbook_runs SET status = 'running'$$), 0::bigint,
    'users cannot update playbook runs');
RESET ROLE;

ROLLBACK;
