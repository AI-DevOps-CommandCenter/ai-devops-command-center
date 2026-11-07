-- 08: New target tables, link columns and indexes (migrations 000100-000300).
BEGIN;

SELECT tests.remember('incident', 'c0000000-0000-4000-8000-000000000001');
SELECT tests.remember('run', 'f0000000-0000-4000-8000-000000000001');
SELECT tests.remember('u1', tests.create_user('t08.u1@example.test', 'user'));
SELECT tests.remember('adm', 'a0000000-0000-4000-8000-000000000001');

-- Structure
SELECT tests.ok(
    (SELECT count(*) = 3 FROM pg_tables WHERE schemaname = 'public'
       AND tablename IN ('automation_runs', 'incident_events', 'notification_deliveries') AND rowsecurity),
    'the 3 target tables exist with RLS enabled');
SELECT tests.is(
    (SELECT string_agg(tablename || ':' || cmd, ',') FROM pg_policies WHERE schemaname = 'public'
       AND tablename IN ('automation_runs', 'incident_events', 'notification_deliveries')),
    'incident_events:SELECT', 'only policy on the new tables: timeline read (A7); the others are function-only');
SELECT tests.is((SELECT count(*)::int FROM pg_tables WHERE schemaname = 'public'), 22,
    '22 public tables: 18 baseline + 3 target + automation_request_nonces (A5)');

-- No client privileges at all (including TRUNCATE/REFERENCES/TRIGGER/MAINTAIN)
SELECT tests.ok(
    NOT EXISTS (
        SELECT 1
        FROM unnest(ARRAY['automation_runs', 'incident_events', 'notification_deliveries']) AS t(tbl)
        CROSS JOIN unnest(ARRAY['anon', 'authenticated']) AS r(role)
        CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) AS p(priv)
        WHERE has_table_privilege(r.role, 'public.' || t.tbl, p.priv)
          AND NOT (r.role = 'authenticated' AND t.tbl = 'incident_events' AND p.priv = 'SELECT')),
    'no client privileges on the new tables, except SELECT on incident_events for authenticated (A7)');

SELECT tests.login('u1');
SET LOCAL ROLE authenticated;
SELECT tests.throws($$SELECT 1 FROM public.automation_runs$$, '42501', 'clients cannot read automation_runs');
SELECT tests.throws($$INSERT INTO public.incident_events (incident_id, event_type)
                      VALUES ('c0000000-0000-4000-8000-000000000001', 'comment')$$,
    '42501', 'clients cannot write incident_events directly');
SELECT tests.throws($$TRUNCATE public.notification_deliveries$$, '42501', 'clients cannot truncate notification_deliveries');
RESET ROLE;

-- automation_runs: duplicate n8n execution prevention and status values
SELECT tests.lives(format($$INSERT INTO public.automation_runs (workflow_name, n8n_execution_id, incident_id, playbook_run_id)
                            VALUES ('remediation', 'n8n-exec-001', %L, %L)$$, tests.fx('incident'), tests.fx('run')),
    'automation run recorded with its n8n execution id');
SELECT tests.throws($$INSERT INTO public.automation_runs (workflow_name, n8n_execution_id)
                      VALUES ('remediation', 'n8n-exec-001')$$,
    '23505', 'the same n8n execution cannot be recorded twice');
SELECT tests.lives($$INSERT INTO public.automation_runs (workflow_name) VALUES ('investigation'),
                                                                          ('investigation')$$,
    'runs without an n8n execution id yet are allowed (NULLs are not duplicates)');
SELECT tests.throws($$INSERT INTO public.automation_runs (workflow_name, status) VALUES ('x', 'done')$$,
    '23514', 'automation_runs.status rejects unknown values');
SELECT tests.throws($$INSERT INTO public.automation_runs (workflow_name, started_at, completed_at)
                      VALUES ('x', now(), now() - interval '1 minute')$$,
    '23514', 'an automation run cannot complete before it started');
SELECT tests.lives($$INSERT INTO public.automation_runs (workflow_name, status, error_message)
                     VALUES ('remediation', 'failed', 'synthetic failure')$$,
    'a failed automation run can be recorded with its error');

-- incident_events
SELECT tests.lives(format($$INSERT INTO public.incident_events (incident_id, event_type, level, message, actor_id)
                            VALUES (%L, 'status_change', 'info', 'open -> investigating', %L)$$,
                          tests.fx('incident'), tests.fx('adm')),
    'timeline event recorded');
SELECT tests.throws(format($$INSERT INTO public.incident_events (incident_id, event_type) VALUES (%L, 'gossip')$$,
                           tests.fx('incident')),
    '23514', 'incident_events.event_type rejects unknown values');
SELECT tests.throws(format($$INSERT INTO public.incident_events (incident_id, event_type, level) VALUES (%L, 'log', 'debug')$$,
                           tests.fx('incident')),
    '23514', 'incident_events.level rejects unknown values');
SELECT tests.throws(format($$DELETE FROM public.incidents WHERE id = %L$$, tests.fx('incident')),
    '23001', 'an incident with timeline or automation history cannot be deleted (RESTRICT)');

-- notification_deliveries
INSERT INTO public.notifications (id, user_id, incident_id, title, message)
VALUES ('f0800000-0000-4000-8000-000000000001', tests.fx('u1'), tests.fx('incident'), 'Synthetic', 'Synthetic message');
INSERT INTO public.device_tokens (id, user_id, device_token, platform)
VALUES ('f0800000-0000-4000-8000-000000000002', tests.fx('u1'), 'synthetic-device-token', 'android');
SELECT tests.lives($$INSERT INTO public.notification_deliveries (notification_id, device_token_id, channel, status, attempt_count)
                     VALUES ('f0800000-0000-4000-8000-000000000001', 'f0800000-0000-4000-8000-000000000002', 'push', 'failed', 1)$$,
    'failed push delivery recorded');
SELECT tests.throws($$INSERT INTO public.notification_deliveries (notification_id, channel)
                      VALUES ('f0800000-0000-4000-8000-000000000001', 'telegram')$$,
    '23514', 'notification_deliveries.channel uses the A6 channel set (no telegram)');
SELECT tests.throws($$INSERT INTO public.notification_deliveries (notification_id, channel, attempt_count)
                      VALUES ('f0800000-0000-4000-8000-000000000001', 'push', -1)$$,
    '23514', 'attempt_count cannot be negative');
DELETE FROM public.device_tokens WHERE id = 'f0800000-0000-4000-8000-000000000002';
SELECT tests.ok(
    (SELECT device_token_id IS NULL FROM public.notification_deliveries
     WHERE notification_id = 'f0800000-0000-4000-8000-000000000001'),
    'removing a device token keeps the delivery record (SET NULL)');
DELETE FROM public.notifications WHERE id = 'f0800000-0000-4000-8000-000000000001';
SELECT tests.is(
    (SELECT count(*) FROM public.notification_deliveries
     WHERE notification_id = 'f0800000-0000-4000-8000-000000000001'),
    0::bigint, 'deliveries are removed with their notification (CASCADE)');

-- Link columns
SELECT tests.ok(
    (SELECT count(*) = 5 FROM information_schema.columns
     WHERE table_schema = 'public' AND is_nullable = 'YES'
       AND (table_name, column_name) IN (('ai_analyses','investigation_id'),
            ('recovery_checks','playbook_run_id'), ('recovery_checks','automation_run_id'),
            ('recovery_checks','checked_by'), ('playbook_runs','automation_run_id'))),
    'the 5 link columns exist and are nullable');
SELECT tests.ok(
    (SELECT bool_and(automation_run_id IS NULL) FROM public.playbook_runs),
    'existing playbook runs have NULL automation_run_id (untouched)');
SELECT tests.lives(format($$INSERT INTO public.recovery_checks (incident_id, playbook_run_id, status, check_type)
                            VALUES (%L, %L, 'unhealthy', 'http')$$, tests.fx('incident'), tests.fx('run')),
    'a failed recovery check can be linked to its playbook run');
SELECT tests.throws(format($$INSERT INTO public.recovery_checks (incident_id, playbook_run_id, status)
                             VALUES (%L, gen_random_uuid(), 'healthy')$$, tests.fx('incident')),
    '23503', 'recovery_checks.playbook_run_id must reference a real run');

-- Indexes from 000100 and the new tables
SELECT tests.is(
    (SELECT count(*)::int FROM pg_indexes WHERE schemaname = 'public' AND indexname IN (
        'idx_approvals_incident_id','idx_approvals_requested_by','idx_approvals_approver_id',
        'idx_audit_logs_actor_id','idx_audit_logs_created_at','idx_audit_logs_entity',
        'idx_incidents_created_by','idx_integrations_created_by',
        'idx_remediation_executions_playbook_id','idx_remediation_executions_triggered_by')),
    10, 'the 10 missing foreign-key/filter indexes exist');
SELECT tests.ok(
    NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        WHERE c.contype = 'f' AND t.relnamespace = 'public'::regnamespace
          AND NOT EXISTS (
              SELECT 1 FROM pg_index i
              WHERE i.indrelid = c.conrelid AND i.indkey[0] = c.conkey[1])),
    'every foreign key in public now has a supporting index');

ROLLBACK;
