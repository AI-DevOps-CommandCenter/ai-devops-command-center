-- 11: Trusted audit log and incident timeline (A7, migrations 000500/000700).
BEGIN;

SELECT tests.remember('u1',  tests.create_user('t11.u1@example.test', 'user'));
SELECT tests.remember('u2',  tests.create_user('t11.u2@example.test', 'user'));
SELECT tests.remember('op',  tests.create_user('t11.op@example.test', 'operator'));
SELECT tests.remember('bot', tests.create_user('t11.bot@example.test', 'automation'));
SELECT tests.remember('adm', 'a0000000-0000-4000-8000-000000000001');

SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
INSERT INTO public.incidents (id, title, service_name, created_by)
VALUES ('c1100000-0000-4000-8000-000000000001', 'u1 incident', 'svc', tests.fx('u1'));
SELECT set_config('fx.r1', public.request_playbook_run('c1100000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000001', NULL, '{"target": "svc", "api_key": "should-not-leak"}')::text, true);
SELECT tests.remember('run1', (current_setting('fx.r1')::jsonb ->> 'run_id')::uuid);
SELECT tests.remember('appr1', (current_setting('fx.r1')::jsonb ->> 'approval_id')::uuid);
RESET ROLE;

-- Actor comes from the JWT; entry written with the action.
SELECT tests.ok(EXISTS (SELECT 1 FROM public.audit_logs
                        WHERE action = 'PLAYBOOK_RUN_REQUESTED' AND entity_id = tests.fx('run1')
                          AND actor_id = tests.fx('u1') AND details ->> 'actor_role' = 'user'),
    'the request is audited with the caller as actor and their role');
SELECT tests.ok(NOT EXISTS (SELECT 1 FROM public.audit_logs WHERE details::text LIKE '%should-not-leak%'),
    'request payload secrets never reach the audit log');

-- Fail closed: if the audit entry cannot be written, the action does not happen.
CREATE FUNCTION tests.break_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'audit store unavailable'; END $$;
CREATE TRIGGER zz_break_audit BEFORE INSERT ON public.audit_logs
    FOR EACH ROW EXECUTE FUNCTION tests.break_audit();
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.decide_approval(%L, 'approved')$$, tests.fx('appr1')),
    'P0001', 'when the audit write fails, the decision fails');
RESET ROLE;
DROP TRIGGER zz_break_audit ON public.audit_logs;
SELECT tests.is((SELECT status FROM public.approvals WHERE id = tests.fx('appr1')), 'pending',
    'ATOMIC: the approval is still pending (nothing committed without its audit entry)');
SELECT tests.is((SELECT status FROM public.playbook_runs WHERE id = tests.fx('run1')), 'pending_approval',
    'ATOMIC: the run is unchanged');

SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT public.decide_approval(tests.fx('appr1'), 'approved', 'ok');
RESET ROLE;
SELECT tests.ok(EXISTS (SELECT 1 FROM public.audit_logs WHERE action = 'APPROVAL_APPROVED'
                          AND entity_id = tests.fx('appr1') AND actor_id = tests.fx('op')),
    'the decision is audited with the approver as actor');

-- Redaction of machine payloads
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT public.start_playbook_run(tests.fx('run1'), 'n8n-11-001');
SELECT public.complete_playbook_run(tests.fx('run1'), 'success',
    '{"restarted": true, "access_token": "should-not-leak"}', 'n8n-11-001');
RESET ROLE;
SELECT tests.ok((SELECT NOT (result_payload ? 'access_token') AND (result_payload ->> 'restarted') = 'true'
                 FROM public.playbook_runs WHERE id = tests.fx('run1')),
    'credential-like keys are removed from stored results');

-- Append-only for every role, including the owner.
SELECT tests.clear_claims();
SELECT tests.throws($$UPDATE public.audit_logs SET action = 'X'$$, 'DC403', 'owner cannot update audit_logs');
SELECT tests.throws($$DELETE FROM public.audit_logs$$, 'DC403', 'owner cannot delete audit_logs');
SELECT tests.throws($$TRUNCATE public.audit_logs$$, 'DC403', 'owner cannot truncate audit_logs');
SELECT tests.throws($$UPDATE public.incident_events SET message = 'X'$$, 'DC403', 'owner cannot update incident_events');
SELECT tests.throws($$DELETE FROM public.incident_events$$, 'DC403', 'owner cannot delete incident_events');
SELECT tests.throws($$TRUNCATE public.incident_events$$, 'DC403', 'owner cannot truncate incident_events');
SELECT tests.ok(NOT has_function_privilege('authenticated', 'public.log_audit_event(text,text,uuid,jsonb)', 'EXECUTE')
            AND NOT has_function_privilege('authenticated', 'public.write_incident_event(uuid,text,text,jsonb,text)', 'EXECUTE'),
    'the internal writers cannot be called by clients');

-- Timeline
SELECT tests.is((SELECT string_agg(event_type, ',' ORDER BY occurred_at, created_at, event_type)
                 FROM public.incident_events WHERE incident_id = 'c1100000-0000-4000-8000-000000000001'),
    'approval,approval,remediation,remediation', 'the workflow wrote the incident timeline');

SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar($$SELECT count(*) FROM public.incident_events
                               WHERE incident_id = 'c1100000-0000-4000-8000-000000000001'$$), 4::bigint,
    'the incident owner reads the timeline');
SELECT tests.throws($$INSERT INTO public.incident_events (incident_id, event_type)
                      VALUES ('c1100000-0000-4000-8000-000000000001', 'comment')$$,
    '42501', 'clients cannot write the timeline directly');
SELECT tests.throws($$SELECT public.add_incident_event('c1100000-0000-4000-8000-000000000001', 'comment', 'hi')$$,
    'DC403', 'users cannot add timeline events');
RESET ROLE;
SELECT tests.login('u2');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.incident_events'), 0::bigint,
    'other users cannot read the timeline');
RESET ROLE;
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.lives($$SELECT public.add_incident_event('c1100000-0000-4000-8000-000000000001', 'comment', 'Looking into it')$$,
    'a manager adds a comment');
SELECT tests.throws($$SELECT public.add_incident_event('c1100000-0000-4000-8000-000000000001', 'status_change', 'x')$$,
    'DC403', 'managers cannot fake status events');
RESET ROLE;
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.lives($$SELECT public.add_incident_event('c1100000-0000-4000-8000-000000000001', 'log', 'Collected logs', '{"lines": 120}')$$,
    'automation adds an operational event');
SELECT tests.throws($$SELECT public.add_incident_event('c1100000-0000-4000-8000-000000000001', 'approval', 'approved!')$$,
    'DC403', 'automation cannot fake approval events');
RESET ROLE;
SELECT tests.is((SELECT source || '/' || actor_id::text FROM public.incident_events
                 WHERE incident_id = 'c1100000-0000-4000-8000-000000000001' AND event_type = 'log'),
    'automation/' || tests.fx('bot')::text, 'timeline source and actor come from the JWT');

-- Deleting a user keeps the decided approval and the audit trail.
SELECT tests.clear_claims();
DELETE FROM auth.users WHERE id = tests.fx('op');
SELECT tests.is((SELECT status || '/' || coalesce(approver_id::text, 'null') FROM public.approvals WHERE id = tests.fx('appr1')),
    'approved/null', 'a deleted approver: the decision stays, only the link is cleared');
SELECT tests.ok(EXISTS (SELECT 1 FROM public.audit_logs WHERE action = 'APPROVAL_APPROVED'
                          AND entity_id = tests.fx('appr1') AND actor_id = tests.fx('op')),
    'the audit entry still names the deleted approver (A7-Q3)');

ROLLBACK;
