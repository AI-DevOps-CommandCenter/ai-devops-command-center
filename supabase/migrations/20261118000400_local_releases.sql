-- =============================================================================
-- Migration: local releases in public.deployments (deployment correlation)
--
-- monitoring/scripts/release.sh records each local release (deploy-bad = v2,
-- reset = v1) through POST /api/machine/deployments, signed like the other
-- automation requests. Workflow 04 reads the releases shortly before an
-- incident through GET /api/machine/deployments, so the root cause analysis
-- (05) sees "a new version went out just before the errors" and can recommend
-- a rollback instead of a restart.
--
--   deployments.service_name, deployments.version   new columns (the table had
--                                                    no service name or version)
--   record_deployment(...)                          automation only, writes an audit entry
--   list_recent_deployments(...)                    automation only, at most 20 rows
--
-- The table keeps its existing columns, constraints and privileges (no client
-- access). Rollback: database/rollback/20261118000400_local_releases.down.sql
-- =============================================================================

-- 1. Schema ------------------------------------------------------------------
ALTER TABLE public.deployments ADD COLUMN IF NOT EXISTS service_name text;
ALTER TABLE public.deployments ADD COLUMN IF NOT EXISTS version text;

ALTER TABLE public.deployments
    ADD CONSTRAINT deployments_service_name_check
        CHECK (service_name IS NULL OR service_name ~ '^[A-Za-z0-9_.:-]{1,100}$'),
    ADD CONSTRAINT deployments_version_check
        CHECK (version IS NULL OR version ~ '^[A-Za-z0-9_.+-]{1,64}$');

CREATE INDEX IF NOT EXISTS idx_deployments_service_name_completed_at
    ON public.deployments (service_name, completed_at DESC)
    WHERE service_name IS NOT NULL;

-- 2. Record a release --------------------------------------------------------------
CREATE FUNCTION public.record_deployment(
    p_service_name text,
    p_version text,
    p_status text DEFAULT 'success',
    p_provider text DEFAULT 'local'
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['automation']);
    v_id uuid;
BEGIN
    IF p_service_name IS NULL OR p_service_name !~ '^[A-Za-z0-9_.:-]{1,100}$' THEN
        RAISE EXCEPTION 'service_name must be 1 to 100 characters (letters, digits, _ . : -).'
            USING ERRCODE = 'DC422';
    END IF;
    IF p_version IS NULL OR p_version !~ '^[A-Za-z0-9_.+-]{1,64}$' THEN
        RAISE EXCEPTION 'version must be 1 to 64 characters (letters, digits, _ . + -).'
            USING ERRCODE = 'DC422';
    END IF;
    IF p_status IS NULL OR p_status NOT IN ('success', 'failed') THEN
        RAISE EXCEPTION 'Status must be success or failed.' USING ERRCODE = 'DC422';
    END IF;
    IF p_provider IS NULL OR p_provider !~ '^[a-z0-9_-]{1,30}$' THEN
        RAISE EXCEPTION 'provider must be 1 to 30 characters (a-z, 0-9, _ -).' USING ERRCODE = 'DC422';
    END IF;

    INSERT INTO public.deployments (service_name, version, provider, status, started_at, completed_at)
    VALUES (p_service_name, p_version, p_provider, p_status, now(), now())
    RETURNING id INTO v_id;

    PERFORM public.log_audit_event('DEPLOYMENT_RECORDED', 'deployment', v_id,
        jsonb_build_object('service_name', p_service_name, 'version', p_version,
                           'status', p_status, 'provider', p_provider, 'recorded_by', v_uid));

    RETURN v_id;
END;
$$;

-- 3. Read recent releases (workflow 04) ---------------------------------------------
CREATE FUNCTION public.list_recent_deployments(
    p_service_name text,
    p_since timestamptz,
    p_until timestamptz
) RETURNS TABLE (
    id uuid,
    service_name text,
    version text,
    provider text,
    status text,
    completed_at timestamptz
)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
    PERFORM public.require_app_role(ARRAY['automation']);

    IF p_service_name IS NULL OR p_service_name !~ '^[A-Za-z0-9_.:-]{1,100}$' THEN
        RAISE EXCEPTION 'service_name must be 1 to 100 characters (letters, digits, _ . : -).'
            USING ERRCODE = 'DC422';
    END IF;
    IF p_since IS NULL OR p_until IS NULL OR p_since > p_until
       OR p_until - p_since > interval '7 days' THEN
        RAISE EXCEPTION 'since and until are required, since <= until, at most 7 days apart.'
            USING ERRCODE = 'DC422';
    END IF;

    RETURN QUERY
        SELECT d.id, d.service_name, d.version, d.provider, d.status, d.completed_at
          FROM public.deployments d
         WHERE d.service_name = p_service_name
           AND d.completed_at BETWEEN p_since AND p_until
         ORDER BY d.completed_at DESC
         LIMIT 20;
END;
$$;

-- 4. Function privileges ------------------------------------------------------------
REVOKE ALL ON FUNCTION
    public.record_deployment(text, text, text, text),
    public.list_recent_deployments(text, timestamptz, timestamptz)
FROM PUBLIC, anon, authenticated;

-- require_app_role(['automation']) inside each function limits them to the
-- automation identity (which signs in as authenticated).
GRANT EXECUTE ON FUNCTION
    public.record_deployment(text, text, text, text),
    public.list_recent_deployments(text, timestamptz, timestamptz)
TO authenticated;
