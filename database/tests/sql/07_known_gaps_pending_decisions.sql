-- 07: CHARACTERISATION of known gaps in the CURRENT database.
--
-- Each assertion confirms behaviour that the pending decisions (A2/A3/A4/A7)
-- are meant to remove. They pass today because they describe today's
-- behaviour. When a decision is implemented, the matching assertion must be
-- flipped to expect an error (see database/DATABASE_TEAM_HANDOVER.md).
BEGIN;

SELECT tests.remember('u1', tests.create_user('t07.u1@example.test', 'user'));
SELECT tests.remember('op', tests.create_user('t07.op@example.test', 'operator'));

SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
INSERT INTO public.incidents (id, title, service_name, created_by)
VALUES ('c0700000-0000-4000-8000-000000000001', 'u1 incident', 'svc', tests.fx('u1'));

SELECT tests.lives(format($$INSERT INTO public.approvals (incident_id, requested_by, approver_id, status)
                            VALUES ('c0700000-0000-4000-8000-000000000001', %1$L, %1$L, 'approved')$$, tests.fx('u1')),
    'GAP-01 (A2/A3): a user can insert an approval that is already approved by themselves');

SELECT tests.lives(format($$INSERT INTO public.playbook_runs (playbook_id, incident_id, requested_by, approved_by, status)
                            VALUES ('e0000000-0000-4000-8000-000000000001', 'c0700000-0000-4000-8000-000000000001',
                                    %1$L, %1$L, 'approved')$$, tests.fx('u1')),
    'GAP-02 (A2/A3): a user can insert a self-approved playbook run directly');

SELECT tests.lives($$INSERT INTO public.playbook_runs (playbook_id, incident_id, requested_by)
                     VALUES ('e0000000-0000-4000-8000-000000000004', 'c0700000-0000-4000-8000-000000000001',
                             auth.uid())$$,
    'GAP-03 (A4): a run can be requested for a disabled playbook (enabled check is backend-only)');

SELECT tests.lives($$INSERT INTO public.playbook_runs (playbook_id, incident_id, requested_by)
                     VALUES ('e0000000-0000-4000-8000-000000000002', 'c0700000-0000-4000-8000-000000000001', auth.uid()),
                            ('e0000000-0000-4000-8000-000000000002', 'c0700000-0000-4000-8000-000000000001', auth.uid())$$,
    'GAP-04 (A3): duplicate active runs for the same incident and playbook are allowed');

SELECT tests.lives($$INSERT INTO public.audit_logs (actor_id, action, details)
                     VALUES (auth.uid(), 'APPROVAL_DECIDED', '{"forged": true}')$$,
    'GAP-05 (A7): a user can write arbitrary audit entries under their own identity');
RESET ROLE;

SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.lives($$INSERT INTO public.remediation_executions (incident_id, status, started_at, completed_at)
                     VALUES ('c0700000-0000-4000-8000-000000000001', 'succeeded', now(), now())$$,
    'GAP-06 (A3): a manager can record a succeeded remediation with no approval and client-set timestamps');
SELECT tests.is(tests.affected($$UPDATE public.incidents SET status = 'open'
                                 WHERE id = 'c0000000-0000-4000-8000-000000000003'$$), 1::bigint,
    'GAP-07 (A3/U11): invalid incident transitions (resolved -> open) are not blocked');
SELECT tests.is(tests.affected($$UPDATE public.incidents SET status = 'resolved'
                                 WHERE id = 'c0700000-0000-4000-8000-000000000001'$$), 1::bigint,
    'GAP-08 (U11): an incident can be resolved without a healthy recovery check');
RESET ROLE;

-- Owner-level (not client) gaps
SELECT tests.is(tests.affected($$UPDATE public.audit_logs SET action = 'rewritten'
                                 WHERE details ->> 'sequence' = '1'$$), 1::bigint,
    'GAP-09 (A7): audit rows are not append-only for privileged roles (no immutability trigger)');
SELECT tests.lives($$INSERT INTO public.approvals (incident_id, requested_by, approver_id, status)
                     VALUES ('c0000000-0000-4000-8000-000000000002',
                             'a0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002', 'approved')$$,
    'GAP-10 (A3): no constraint stops approver = requester outside the API policies');

ROLLBACK;
