-- 02: Client privileges on the baseline tables and functions, after all
--     migrations. Baseline values come from the verified live baseline
--     (checklist P3 / P3c); changes made by the A2-A7 migrations are marked.
BEGIN;

WITH expected(tbl, privs) AS (VALUES
    ('ai_analyses',            'SELECT'),                 -- A2 read (000700), was none
    ('approvals',              'SELECT'),                 -- A2-Q3: writes via functions (000700)
    ('audit_log',              ''),
    ('audit_logs',             'SELECT'),                 -- A2-Q3/A7: no client INSERT (000500)
    ('deployments',            ''),
    ('device_tokens',          'SELECT'),                 -- A6 read own (000600), was none
    ('incident_logs',          'INSERT,SELECT'),
    ('incidents',              'INSERT,SELECT,UPDATE'),
    ('integrations',           'DELETE,INSERT,SELECT,UPDATE'),
    ('investigations',         'INSERT,SELECT,UPDATE'),
    ('notifications',          'SELECT'),                 -- A6 read own (000600), was none
    ('playbook_runs',          'SELECT'),                 -- A2-Q3: writes via functions (000700)
    ('playbooks',              'DELETE,INSERT,SELECT,UPDATE'),
    ('postmortems',            'INSERT,SELECT,UPDATE'),
    ('profiles',               'SELECT'),
    ('recovery_checks',        'SELECT'),                 -- A2 read (000700), was none
    ('remediation_executions', 'SELECT'),                 -- A2-Q3: legacy, read only (000700)
    ('services',               '')
),
actual AS (
    SELECT e.tbl,
           coalesce(string_agg(p, ',' ORDER BY p)
                    FILTER (WHERE has_table_privilege('authenticated', format('public.%I', e.tbl), p)), '') AS auth_privs,
           coalesce(string_agg(p, ',' ORDER BY p)
                    FILTER (WHERE has_table_privilege('anon', format('public.%I', e.tbl), p)), '') AS anon_privs
    FROM expected e
    CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN']) AS p
    GROUP BY e.tbl
)
SELECT tests.is(a.auth_privs, e.privs, format('authenticated privileges on %s = {%s}', e.tbl, e.privs))
     , tests.is(a.anon_privs, '', format('anon has no privileges on %s', e.tbl))
FROM expected e JOIN actual a USING (tbl)
ORDER BY e.tbl;

WITH expected(fn, anon_ok, auth_ok) AS (VALUES
    ('public.admin_update_user_role(uuid,text)', false, true),
    ('public.handle_new_user()',                 true,  true),
    ('public.is_admin()',                        false, true),
    ('public.is_incident_manager()',             false, true),
    ('public.rls_auto_enable()',                 true,  true),
    ('public.set_updated_at()',                  true,  true)
)
SELECT tests.is(has_function_privilege('anon', fn, 'EXECUTE'), anon_ok,
                format('anon EXECUTE on %s = %s', fn, anon_ok))
     , tests.is(has_function_privilege('authenticated', fn, 'EXECUTE'), auth_ok,
                format('authenticated EXECUTE on %s = %s', fn, auth_ok))
FROM expected;

ROLLBACK;
