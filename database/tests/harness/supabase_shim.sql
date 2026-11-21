-- =============================================================================
-- Minimal Supabase compatibility shim for PLAIN PostgreSQL test clusters.
--
-- Provides only what the migrations reference: the anon/authenticated/
-- service_role roles, an `auth` schema with `auth.users`, and `auth.uid()`,
-- `auth.role()`, `auth.jwt()` implemented the same way Supabase does
-- (from the `request.jwt.claims` setting).
--
-- NEVER run this on a Supabase project (local stack, staging or production):
-- Supabase provides the real objects. The guard below refuses to run if an
-- `auth` schema already exists.
-- =============================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'auth') THEN
        RAISE EXCEPTION 'auth schema already exists: this shim is only for plain PostgreSQL test clusters';
    END IF;
END
$$;

CREATE ROLE anon NOLOGIN NOINHERIT;
CREATE ROLE authenticated NOLOGIN NOINHERIT;
CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
CREATE ROLE supabase_auth_admin NOLOGIN NOINHERIT;

CREATE SCHEMA extensions;
CREATE SCHEMA auth AUTHORIZATION supabase_auth_admin;

CREATE TABLE auth.users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text,
    raw_user_meta_data jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);
ALTER TABLE auth.users OWNER TO supabase_auth_admin;

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
    SELECT coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
    SELECT nullif(
        coalesce(
            current_setting('request.jwt.claim.sub', true),
            auth.jwt() ->> 'sub'
        ),
        ''
    )::uuid
$$;

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
    SELECT nullif(
        coalesce(
            current_setting('request.jwt.claim.role', true),
            auth.jwt() ->> 'role'
        ),
        ''
    )::text
$$;

GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.jwt(), auth.uid(), auth.role() TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA extensions TO anon, authenticated, service_role;
