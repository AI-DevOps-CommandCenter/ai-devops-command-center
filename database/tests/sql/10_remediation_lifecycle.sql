-- 10: Remediation lifecycle (A3/A4, migration 000700): idempotency, duplicate
--     execution prevention, approval bypass attempts, manual override, cancel.
BEGIN;

SELECT tests.remember('u1',  tests.create_user('t10.u1@example.test', 'user'));
SELECT tests.remember('u2',  tests.create_user('t10.u2@example.test', 'user'));
SELECT tests.remember('op',  tests.create_user('t10.op@example.test', 'operator'));
SELECT tests.remember('bot', tests.create_user('t10.bot@example.test', 'automation'));
SELECT tests.remember('adm', 'a0000000-0000-4000-8000-000000000001');

-- Playbooks (seed): e..01 restart, e..02 rollback, e..03 scale,
-- e..04 circuit breaker (disabled), e..05 restart WITHOUT requires_approval.
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
INSERT INTO public.incidents (id, title, service_name, created_by)
VALUES ('c1000000-0000-4000-8000-000000000001', 'u1 incident', 'svc', tests.fx('u1'));

-- Idempotency
SELECT set_config('fx.r1', public.request_playbook_run('c1000000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000001', 'mobile-key-0001', '{"target": "svc"}')::text, true);
SELECT tests.remember('run1', (current_setting('fx.r1')::jsonb ->> 'run_id')::uuid);
SELECT tests.remember('appr1', (current_setting('fx.r1')::jsonb ->> 'approval_id')::uuid);
SELECT tests.is((current_setting('fx.r1')::jsonb ->> 'created'), 'true', 'first request creates a run');
SELECT tests.is((public.request_playbook_run('c1000000-0000-4000-8000-000000000001',
                 'e0000000-0000-4000-8000-000000000001', 'mobile-key-0001') ->> 'run_id')::uuid,
    tests.fx('run1'), 'a retry with the same idempotency key returns the same run');
SELECT tests.throws($$SELECT public.request_playbook_run('c1000000-0000-4000-8000-000000000001',
                      'e0000000-0000-4000-8000-000000000002', 'mobile-key-0001')$$,
    'DC409', 'the same key for a different request is rejected');
SELECT tests.throws($$SELECT public.request_playbook_run('c1000000-0000-4000-8000-000000000001',
                      'e0000000-0000-4000-8000-000000000001', 'short')$$,
    'DC422', 'idempotency keys must be 8 to 200 characters');

-- A4: approval for every action, even if the playbook says it is not needed.
SELECT set_config('fx.r2', public.request_playbook_run('c1000000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000005')::text, true);
SELECT tests.remember('run2', (current_setting('fx.r2')::jsonb ->> 'run_id')::uuid);
SELECT tests.remember('appr2', (current_setting('fx.r2')::jsonb ->> 'approval_id')::uuid);
SELECT tests.is(current_setting('fx.r2')::jsonb ->> 'status', 'pending_approval',
    'A4: a playbook with requires_approval = false still needs a human approval');

-- Visibility and state checks
SELECT tests.throws($$SELECT public.request_playbook_run('c0000000-0000-4000-8000-000000000002',
                      'e0000000-0000-4000-8000-000000000001')$$,
    'DC404', 'a user cannot request remediation for someone else''s incident');
SELECT tests.throws(format($$SELECT public.start_playbook_run(%L, 'n8n-10-x')$$, tests.fx('run1')),
    'DC403', 'a user cannot start a run');
RESET ROLE;

SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.request_playbook_run('c0000000-0000-4000-8000-000000000003',
                      'e0000000-0000-4000-8000-000000000001')$$,
    'DC409', 'no remediation on a resolved incident');
RESET ROLE;

-- Start before approval is refused.
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.start_playbook_run(%L, 'n8n-10-001')$$, tests.fx('run1')),
    'DC409', 'BYPASS: a pending run cannot be started');
RESET ROLE;

-- Approve both runs.
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT public.decide_approval(tests.fx('appr1'), 'approved', 'ok');
SELECT public.decide_approval(tests.fx('appr2'), 'approved', 'ok');
RESET ROLE;

-- Start and duplicate-execution prevention.
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.is(public.start_playbook_run(tests.fx('run1'), 'n8n-10-001') ->> 'status', 'running',
    'the automation identity starts an approved run');
SELECT tests.throws(format($$SELECT public.start_playbook_run(%L, 'n8n-10-002')$$, tests.fx('run1')),
    'DC409', 'DUPLICATE: a running run cannot be started again');
SELECT tests.throws(format($$SELECT public.start_playbook_run(%L, 'n8n-10-001')$$, tests.fx('run2')),
    '23505', 'DUPLICATE: an n8n execution id cannot start a second run');
RESET ROLE;
SELECT tests.is((SELECT status FROM public.playbook_runs WHERE id = tests.fx('run2')), 'approved',
    'the run whose start failed is still approved (nothing half-done)');

-- Completion rules
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.complete_playbook_run(%L, 'success', '{}', 'n8n-10-999')$$, tests.fx('run1')),
    'DC403', 'n8n must report with the execution id that started the run');
SELECT tests.throws(format($$SELECT public.complete_playbook_run(%L, 'done', '{}', 'n8n-10-001')$$, tests.fx('run1')),
    'DC422', 'status must be success or failed');
RESET ROLE;
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.complete_playbook_run(%L, 'success', '{}', 'n8n-10-001')$$, tests.fx('run1')),
    'DC403', 'a user cannot complete runs');
RESET ROLE;
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.complete_playbook_run(%L, 'success')$$, tests.fx('run1')),
    'DC422', 'manual completion needs a reason (A3-Q3)');
RESET ROLE;
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.lives(format($$SELECT public.complete_playbook_run(%L, 'success', '{"restarted": true}', 'n8n-10-001')$$,
                          tests.fx('run1')),
    'n8n completes the run');
SELECT tests.throws(format($$SELECT public.complete_playbook_run(%L, 'failed', '{}', 'n8n-10-001')$$, tests.fx('run1')),
    'DC409', 'a finished run cannot be completed again');
RESET ROLE;
SELECT tests.is((SELECT r.status || '/' || a.status FROM public.playbook_runs r
                 JOIN public.automation_runs a ON a.id = r.automation_run_id WHERE r.id = tests.fx('run1')),
    'success/success', 'run and automation record agree');

-- Manual override (A3-Q3)
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT public.start_playbook_run(tests.fx('run2'), 'n8n-10-003');
RESET ROLE;
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.lives(format($$SELECT public.complete_playbook_run(%L, 'failed', '{}', NULL, 'n8n crashed, checked by hand')$$,
                          tests.fx('run2')),
    'an operator completes a stuck run manually with a reason');
RESET ROLE;
SELECT tests.ok(EXISTS (SELECT 1 FROM public.audit_logs WHERE action = 'PLAYBOOK_RUN_COMPLETED_MANUALLY'
                          AND entity_id = tests.fx('run2') AND actor_id = tests.fx('op')
                          AND details ->> 'reason' = 'n8n crashed, checked by hand'),
    'the manual override is audited with its reason');

-- Cancellation
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT set_config('fx.r3', public.request_playbook_run('c1000000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000003')::text, true);
SELECT tests.remember('run3', (current_setting('fx.r3')::jsonb ->> 'run_id')::uuid);
SELECT tests.lives(format($$SELECT public.cancel_playbook_run(%L, 'not needed')$$, tests.fx('run3')),
    'the requester cancels a pending run');
SELECT tests.is((SELECT status FROM public.approvals WHERE playbook_run_id = tests.fx('run3')), 'cancelled',
    'cancelling the run cancels its approval');
SELECT tests.lives($$SELECT public.request_playbook_run('c1000000-0000-4000-8000-000000000001',
                     'e0000000-0000-4000-8000-000000000003')$$,
    'after a cancel, the same playbook can be requested again');
SELECT set_config('fx.r4', public.request_playbook_run('c1000000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000002')::text, true);
SELECT tests.remember('run4', (current_setting('fx.r4')::jsonb ->> 'run_id')::uuid);
SELECT tests.remember('appr4', (current_setting('fx.r4')::jsonb ->> 'approval_id')::uuid);
RESET ROLE;

SELECT tests.login('u2');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.cancel_approval(%L)$$, tests.fx('appr4')),
    'DC403', 'only the requester can cancel an approval request');
SELECT tests.throws(format($$SELECT public.cancel_playbook_run(%L)$$, tests.fx('run4')),
    'DC404', 'another user cannot even see the run');
RESET ROLE;

SELECT tests.login('adm');
SET LOCAL ROLE authenticated;
SELECT public.decide_approval(tests.fx('appr4'), 'approved');
RESET ROLE;
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.cancel_playbook_run(%L, 'changed my mind')$$, tests.fx('run4')),
    'DC403', 'a user cannot cancel an approved run');
SELECT tests.throws(format($$SELECT public.cancel_approval(%L)$$, tests.fx('appr4')),
    'DC409', 'a decided approval cannot be cancelled');
RESET ROLE;
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.cancel_playbook_run(%L)$$, tests.fx('run4')),
    'DC422', 'cancelling an approved run needs a reason');
SELECT tests.lives(format($$SELECT public.cancel_playbook_run(%L, 'maintenance window')$$, tests.fx('run4')),
    'an operator cancels an approved run with a reason');
RESET ROLE;
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.throws(format($$SELECT public.start_playbook_run(%L, 'n8n-10-004')$$, tests.fx('run4')),
    'DC409', 'a cancelled run cannot be started');
RESET ROLE;

-- Owner-level bypass attempt: an approved run whose approval is not approved.
SELECT tests.clear_claims();
UPDATE public.playbook_runs SET status = 'approved' WHERE id = 'f0000000-0000-4000-8000-000000000001';
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.start_playbook_run('f0000000-0000-4000-8000-000000000001', 'n8n-10-005')$$,
    'DC409', 'BYPASS: a run marked approved without an approved approval cannot start (A4)');
RESET ROLE;

-- AI analysis and recovery checks (machine functions)
SELECT tests.login('bot');
SET LOCAL ROLE authenticated;
SELECT tests.lives($$SELECT public.record_ai_analysis('c1000000-0000-4000-8000-000000000001', NULL, 'synthetic-model',
                     'Summary', 'Root cause', 'high', 0.8, '["log: 500 errors"]', 'restart')$$,
    'n8n records an AI analysis');
SELECT tests.throws($$SELECT public.record_ai_analysis('c1000000-0000-4000-8000-000000000001', NULL, 'm',
                      's', 'r', 'urgent', 0.5, '[]', 'restart')$$,
    '23514', 'AI severity outside the allowed set is rejected');
SELECT tests.throws($$SELECT public.record_ai_analysis('c1000000-0000-4000-8000-000000000001',
                      'd0000000-0000-4000-8000-000000000003', 'm', 's', 'r', 'low', 0.5, '[]', 'restart')$$,
    'DC422', 'the investigation must belong to the incident');
SELECT tests.lives(format($$SELECT public.record_recovery_check('c1000000-0000-4000-8000-000000000001', %L,
                            'healthy', 'http', '{"latency_ms": 120}')$$, tests.fx('run1')),
    'n8n records a healthy recovery check for the run');
RESET ROLE;
SELECT tests.login('op');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT public.record_ai_analysis('c1000000-0000-4000-8000-000000000001', NULL, 'm',
                      's', 'r', 'low', 0.5, '[]', 'restart')$$,
    'DC403', 'humans cannot submit AI analyses');
RESET ROLE;
SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar($$SELECT count(*) FROM public.ai_analyses
                               WHERE incident_id = 'c1000000-0000-4000-8000-000000000001'$$), 1::bigint,
    'the incident owner can read the AI analysis');
SELECT tests.is(tests.scalar($$SELECT count(*) FROM public.recovery_checks
                               WHERE incident_id = 'c1000000-0000-4000-8000-000000000001'$$), 1::bigint,
    'the incident owner can read the recovery check');
SELECT tests.throws($$SELECT public.record_recovery_check('c1000000-0000-4000-8000-000000000001', NULL, 'healthy')$$,
    'DC403', 'users cannot record recovery checks');
RESET ROLE;
SELECT tests.login('u2');
SET LOCAL ROLE authenticated;
SELECT tests.is(tests.scalar('SELECT count(*) FROM public.ai_analyses'), 0::bigint,
    'other users cannot read the analysis');
RESET ROLE;

ROLLBACK;
