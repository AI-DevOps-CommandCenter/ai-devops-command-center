-- =============================================================================
-- Test helpers (schema `tests`). Test-only; never part of migrations.
-- Works on plain PostgreSQL (with the shim) and on the local Supabase stack.
--
-- Each assertion prints "ok - <description>" as a NOTICE, or raises
-- "not ok - <description>", which stops the test file (psql ON_ERROR_STOP).
-- =============================================================================

DROP SCHEMA IF EXISTS tests CASCADE;
CREATE SCHEMA tests;

CREATE FUNCTION tests.ok(condition boolean, description text) RETURNS void
    LANGUAGE plpgsql AS $$
BEGIN
    IF condition IS NOT TRUE THEN
        RAISE EXCEPTION 'not ok - %', description;
    END IF;
    RAISE NOTICE 'ok - %', description;
END
$$;

CREATE FUNCTION tests.is(have anyelement, want anyelement, description text) RETURNS void
    LANGUAGE plpgsql AS $$
BEGIN
    IF have IS DISTINCT FROM want THEN
        RAISE EXCEPTION 'not ok - % (have: %, want: %)', description, have, want;
    END IF;
    RAISE NOTICE 'ok - %', description;
END
$$;

-- Executes `statement` as the CURRENT role and expects it to fail.
-- expected_state: SQLSTATE (e.g. '42501' insufficient privilege,
-- '23514' check violation, '23505' unique violation, '23503' FK violation,
-- 'P0001' raise_exception) or NULL for "any error".
CREATE FUNCTION tests.throws(statement text, expected_state text, description text) RETURNS void
    LANGUAGE plpgsql AS $$
BEGIN
    BEGIN
        EXECUTE statement;
    EXCEPTION WHEN OTHERS THEN
        IF expected_state IS NULL OR SQLSTATE = expected_state THEN
            RAISE NOTICE 'ok - % [%]', description, SQLSTATE;
            RETURN;
        END IF;
        RAISE EXCEPTION 'not ok - % (expected SQLSTATE %, got %: %)',
            description, expected_state, SQLSTATE, SQLERRM;
    END;
    RAISE EXCEPTION 'not ok - % (statement succeeded, expected an error)', description;
END
$$;

-- Executes `statement` as the current role and expects it to succeed.
CREATE FUNCTION tests.lives(statement text, description text) RETURNS void
    LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE statement;
    RAISE NOTICE 'ok - %', description;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'not ok - % (% %)', description, SQLSTATE, SQLERRM;
END
$$;

-- Executes a DML statement as the current role; returns affected row count.
CREATE FUNCTION tests.affected(statement text) RETURNS bigint
    LANGUAGE plpgsql AS $$
DECLARE
    n bigint;
BEGIN
    EXECUTE statement;
    GET DIAGNOSTICS n = ROW_COUNT;
    RETURN n;
END
$$;

-- Runs a query as the current role and returns its single bigint result.
CREATE FUNCTION tests.scalar(query text) RETURNS bigint
    LANGUAGE plpgsql AS $$
DECLARE
    result bigint;
BEGIN
    EXECUTE query INTO result;
    RETURN result;
END
$$;

-- Creates a synthetic Supabase Auth user (fires on_auth_user_created, which
-- creates the profile) and sets the profile role. Call as the superuser.
CREATE FUNCTION tests.create_user(email text, role text DEFAULT 'user') RETURNS uuid
    LANGUAGE plpgsql AS $$
DECLARE
    new_id uuid := gen_random_uuid();
BEGIN
    INSERT INTO auth.users (id, email, raw_user_meta_data)
    VALUES (new_id, email, jsonb_build_object('full_name', 'Synthetic ' || role));

    UPDATE public.profiles SET role = create_user.role WHERE id = new_id;

    RETURN new_id;
END
$$;

-- Sets the JWT claims for the current transaction, like PostgREST does.
-- Use together with `SET LOCAL ROLE authenticated;`.
CREATE FUNCTION tests.set_claims(user_id uuid) RETURNS void
    LANGUAGE sql AS $$
    SELECT set_config(
        'request.jwt.claims',
        json_build_object('sub', user_id, 'role', 'authenticated')::text,
        true
    );
$$;

-- Fixture registry (transaction-local settings, readable by every role):
--   SELECT tests.remember('admin', tests.create_user('a@example.test', 'admin'));
--   SELECT tests.fx('admin');            -> uuid
--   SELECT tests.login('admin');         -> sets JWT claims for that user
CREATE FUNCTION tests.remember(name text, id uuid) RETURNS uuid
    LANGUAGE sql AS $$
    SELECT set_config('fx.' || name, id::text, true)::uuid;
$$;

CREATE FUNCTION tests.fx(name text) RETURNS uuid
    LANGUAGE sql STABLE AS $$
    SELECT current_setting('fx.' || name)::uuid;
$$;

CREATE FUNCTION tests.login(name text) RETURNS void
    LANGUAGE sql AS $$
    SELECT tests.set_claims(tests.fx(name));
$$;

CREATE FUNCTION tests.clear_claims() RETURNS void
    LANGUAGE sql AS $$
    SELECT set_config('request.jwt.claims', '', true);
$$;

GRANT USAGE ON SCHEMA tests TO PUBLIC;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA tests TO PUBLIC;
