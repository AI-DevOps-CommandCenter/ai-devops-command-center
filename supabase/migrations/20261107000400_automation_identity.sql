-- =============================================================================
-- Migration: automation identity and shared role helpers
-- Decision:  A5 (approved 2026-11-07): dedicated automation identity; n8n has
--            no database access and no service_role; signed requests with
--            replay protection between n8n and the backend.
--            A5-Q1 answered by A5: new role value `automation`.
-- Rollback:  database/rollback/20261107000400_automation_identity.down.sql
--
-- What this adds:
--   * `automation` as a profiles.role value. It is held by ONE dedicated
--     Supabase Auth user that only the backend signs in as.
--   * Role guard: the automation role can be assigned or removed only by the
--     database owner (SQL Editor / migration), never through the API, so no
--     admin can turn a human into a machine or the machine into an admin.
--     Provisioning, rotation and revocation procedure: A5-Q2 (still open).
--   * Helpers used by the workflow functions of later migrations.
--   * A replay-protection store for signed n8n -> backend requests: the
--     backend (as the automation identity) consumes each request nonce once.
--
-- Error codes (database/API_AND_INTEGRATION_CONTRACTS.md B.1):
--   DC401 not authenticated · DC403 not allowed · DC404 not found
--   DC409 conflict / replay · DC422 invalid input
-- =============================================================================

-- 1. Role value -----------------------------------------------------------------
ALTER TABLE public.profiles DROP CONSTRAINT profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
    CHECK (role = ANY (ARRAY['user'::text, 'admin'::text, 'operator'::text, 'automation'::text]));

-- 2. Role guard -----------------------------------------------------------------
-- Requests through the API always carry a JWT (auth.uid() is set). The owner
-- working in the SQL Editor or a migration has no JWT.
CREATE FUNCTION public.guard_automation_role() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
BEGIN
    IF NEW.role IS DISTINCT FROM OLD.role
       AND (NEW.role = 'automation' OR OLD.role = 'automation')
       AND (SELECT auth.uid()) IS NOT NULL THEN
        RAISE EXCEPTION 'The automation role can only be assigned or removed by the database owner.'
            USING ERRCODE = 'DC403';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER guard_automation_role
    BEFORE UPDATE OF role ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.guard_automation_role();

-- 3. Helpers --------------------------------------------------------------------
-- Role of the caller, or NULL when not signed in / no profile.
CREATE FUNCTION public.current_app_role() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
    SELECT role FROM public.profiles WHERE id = (SELECT auth.uid());
$$;

-- INTERNAL. Returns the caller's id if their role is in p_roles; raises otherwise.
CREATE FUNCTION public.require_app_role(p_roles text[]) RETURNS uuid
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := (SELECT auth.uid());
    v_role text;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = 'DC401';
    END IF;

    SELECT role INTO v_role FROM public.profiles WHERE id = v_uid;

    IF v_role IS NULL OR NOT (v_role = ANY (p_roles)) THEN
        RAISE EXCEPTION 'Your role is not allowed to perform this action.' USING ERRCODE = 'DC403';
    END IF;

    RETURN v_uid;
END;
$$;

-- 4. Replay protection for signed machine requests --------------------------------
CREATE TABLE public.automation_request_nonces (
    nonce text NOT NULL,
    signed_at timestamptz NOT NULL,
    received_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT automation_request_nonces_pkey PRIMARY KEY (nonce),
    CONSTRAINT automation_request_nonces_nonce_length CHECK (length(nonce) BETWEEN 16 AND 200)
);

COMMENT ON TABLE public.automation_request_nonces IS
    'Nonces of signed n8n -> backend requests (A5). Written only by consume_automation_nonce(). No client access. Rows older than 15 minutes are pruned.';

ALTER TABLE public.automation_request_nonces ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.automation_request_nonces FROM PUBLIC, anon, authenticated;

-- Called by the backend, as the automation identity, after it has verified the
-- request's HMAC signature. Rejects requests signed more than 5 minutes away
-- from the database clock, and any nonce that was already used.
CREATE FUNCTION public.consume_automation_nonce(p_nonce text, p_signed_at timestamptz) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
    PERFORM public.require_app_role(ARRAY['automation']);

    IF p_nonce IS NULL OR length(p_nonce) NOT BETWEEN 16 AND 200 THEN
        RAISE EXCEPTION 'Invalid nonce.' USING ERRCODE = 'DC422';
    END IF;

    IF p_signed_at IS NULL OR abs(extract(epoch FROM (now() - p_signed_at))) > 300 THEN
        RAISE EXCEPTION 'Signed request is outside the 5 minute window.' USING ERRCODE = 'DC401';
    END IF;

    DELETE FROM public.automation_request_nonces
    WHERE received_at < now() - interval '15 minutes';

    BEGIN
        INSERT INTO public.automation_request_nonces (nonce, signed_at)
        VALUES (p_nonce, p_signed_at);
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'Replayed request (nonce already used).' USING ERRCODE = 'DC409';
    END;
END;
$$;

-- 5. Privileges -------------------------------------------------------------------
REVOKE ALL ON FUNCTION
    public.guard_automation_role(),
    public.current_app_role(),
    public.require_app_role(text[]),
    public.consume_automation_nonce(text, timestamptz)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.current_app_role()                           TO authenticated;
GRANT EXECUTE ON FUNCTION public.consume_automation_nonce(text, timestamptz)  TO authenticated;
