-- After rolling back every migration except the baseline, the public schema
-- must match the verified baseline object counts again.
DO $$
DECLARE
    n_tables int;
    n_policies int;
    n_functions int;
BEGIN
    SELECT count(*) INTO n_tables FROM pg_tables WHERE schemaname = 'public';
    SELECT count(*) INTO n_policies FROM pg_policies WHERE schemaname = 'public';
    SELECT count(*) INTO n_functions
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public';

    IF n_tables <> 18 OR n_policies <> 31 OR n_functions <> 6 THEN
        RAISE EXCEPTION 'not ok - baseline counts after rollback: tables %, policies %, functions % (want 18, 31, 6)',
            n_tables, n_policies, n_functions;
    END IF;

    RAISE NOTICE 'ok - baseline structure restored (18 tables, 31 policies, 6 functions)';
END
$$;
