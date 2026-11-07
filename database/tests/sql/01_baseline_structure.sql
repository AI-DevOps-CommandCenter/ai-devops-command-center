-- 01: The baseline reproduces the verified live structure.
BEGIN;

SELECT tests.is(
    (SELECT count(*)::int FROM pg_tables WHERE schemaname = 'public'
       AND tablename IN ('ai_analyses','approvals','audit_log','audit_logs','deployments',
           'device_tokens','incident_logs','incidents','integrations','investigations',
           'notifications','playbook_runs','playbooks','postmortems','profiles',
           'recovery_checks','remediation_executions','services')),
    18, 'all 18 verified live tables exist');

SELECT tests.ok(
    NOT EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND NOT rowsecurity),
    'RLS is enabled on every public table');

SELECT tests.is(
    (SELECT count(*)::int FROM pg_policies WHERE schemaname = 'public'
       AND tablename NOT IN ('incident_events','notification_deliveries','automation_runs')),
    31, '31 verified policies on the baseline tables');

SELECT tests.is(
    (SELECT count(*)::int FROM pg_constraint c JOIN pg_class t ON t.oid = c.conrelid
       JOIN pg_namespace n ON n.oid = t.relnamespace
     WHERE n.nspname = 'public' AND c.contype = 'f'
       AND t.relname NOT IN ('incident_events','notification_deliveries','automation_runs')
       AND c.conname IN (
         'ai_analyses_incident_id_fkey','approvals_approver_id_fkey','approvals_incident_id_fkey',
         'approvals_requested_by_fkey','audit_log_user_id_fkey','audit_logs_actor_id_fkey',
         'deployments_deployed_by_fkey','deployments_service_id_fkey','device_tokens_user_id_fkey',
         'incident_logs_incident_id_fkey','incidents_created_by_fkey','incidents_deployment_id_fkey',
         'incidents_service_id_fkey','integrations_created_by_fkey','investigations_incident_id_fkey',
         'notifications_incident_id_fkey','notifications_user_id_fkey','playbook_runs_approved_by_fkey',
         'playbook_runs_incident_id_fkey','playbook_runs_playbook_id_fkey','playbook_runs_requested_by_fkey',
         'postmortems_created_by_fkey','postmortems_incident_id_fkey','profiles_id_fkey',
         'recovery_checks_incident_id_fkey','recovery_checks_service_id_fkey',
         'remediation_executions_incident_id_fkey','remediation_executions_playbook_id_fkey',
         'remediation_executions_triggered_by_fkey')),
    29, 'all 29 verified foreign keys exist');

SELECT tests.is(
    (SELECT confdeltype::text FROM pg_constraint WHERE conname = 'playbook_runs_playbook_id_fkey'),
    'r', 'playbook_runs.playbook_id is ON DELETE RESTRICT');
SELECT tests.is(
    (SELECT confdeltype::text FROM pg_constraint WHERE conname = 'investigations_incident_id_fkey'),
    'c', 'incident children are ON DELETE CASCADE (current live behaviour)');
SELECT tests.is(
    (SELECT confdeltype::text FROM pg_constraint WHERE conname = 'audit_logs_actor_id_fkey'),
    'n', 'audit_logs.actor_id is ON DELETE SET NULL (current live behaviour)');

SELECT tests.ok(
    (SELECT count(*) = 4 FROM pg_constraint WHERE contype = 'u' AND conname IN (
        'device_tokens_device_token_key','playbooks_name_key',
        'postmortems_incident_id_key','profiles_email_key')),
    'the 4 verified UNIQUE constraints exist');

SELECT tests.is(
    (SELECT count(*)::int FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname IN ('admin_update_user_role','handle_new_user',
       'is_admin','is_incident_manager','rls_auto_enable','set_updated_at')),
    6, 'the 6 verified functions exist');

SELECT tests.ok(
    (SELECT bool_and(prosecdef) FROM pg_proc WHERE pronamespace = 'public'::regnamespace
       AND proname IN ('admin_update_user_role','handle_new_user','is_admin',
                       'is_incident_manager','rls_auto_enable'))
    AND NOT (SELECT prosecdef FROM pg_proc WHERE pronamespace = 'public'::regnamespace
               AND proname = 'set_updated_at'),
    'SECURITY DEFINER flags match the live functions');

SELECT tests.ok(
    (SELECT bool_and(proconfig @> ARRAY['search_path=""']) FROM pg_proc
     WHERE pronamespace = 'public'::regnamespace
       AND proname IN ('admin_update_user_role','handle_new_user','is_admin','is_incident_manager')),
    'definer functions pin an empty search_path');

SELECT tests.ok(
    EXISTS (SELECT 1 FROM pg_event_trigger WHERE evtname = 'ensure_rls'
              AND evtevent = 'ddl_command_end' AND evtenabled <> 'D'
              AND evtfoid = 'public.rls_auto_enable()'::regprocedure),
    'event trigger ensure_rls exists and calls rls_auto_enable()');

SELECT tests.ok(
    EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created'
              AND tgrelid = 'auth.users'::regclass AND NOT tgisinternal
              AND tgfoid = 'public.handle_new_user()'::regprocedure),
    'trigger on_auth_user_created exists on auth.users');

SELECT tests.is(
    (SELECT count(*)::int FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
     WHERE c.relnamespace = 'public'::regnamespace AND NOT t.tgisinternal
       AND t.tgname LIKE 'set\_%\_updated\_at'),
    6, 'the 6 verified updated_at triggers exist');

-- ensure_rls behaviour: a new public table gets RLS automatically.
CREATE TABLE public.zz_rls_probe (id int);
SELECT tests.ok(
    (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.zz_rls_probe'::regclass),
    'ensure_rls enables RLS on newly created public tables');

ROLLBACK;
