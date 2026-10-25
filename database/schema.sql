
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. USER PROFILES
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    email TEXT UNIQUE,
    role TEXT NOT NULL DEFAULT 'user'
        CHECK (role IN ('user', 'admin', 'operator')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. MOBILE DEVICE TOKENS
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL
        CHECK (platform IN ('android', 'ios', 'web')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. MONITORED SERVICES
CREATE TABLE IF NOT EXISTS public.services (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    environment TEXT NOT NULL DEFAULT 'development',
    endpoint TEXT,
    status TEXT NOT NULL DEFAULT 'unknown'
        CHECK (status IN ('healthy', 'degraded', 'down', 'unknown')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. DEPLOYMENTS
CREATE TABLE IF NOT EXISTS public.deployments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id UUID REFERENCES public.services(id) ON DELETE SET NULL,
    provider TEXT,
    repository TEXT,
    branch TEXT,
    commit_sha TEXT,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'running', 'success', 'failed', 'cancelled')),
    deployed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. INCIDENTS
CREATE TABLE IF NOT EXISTS public.incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id UUID REFERENCES public.services(id) ON DELETE SET NULL,
    deployment_id UUID REFERENCES public.deployments(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    severity TEXT NOT NULL DEFAULT 'medium'
        CHECK (severity IN ('critical', 'high', 'medium', 'low', 'info')),
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'investigating', 'identified', 'mitigating', 'resolved', 'closed')),
    source TEXT,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. AI ANALYSES
CREATE TABLE IF NOT EXISTS public.ai_analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
    model_name TEXT,
    summary TEXT,
    root_cause TEXT,
    confidence NUMERIC(5,2)
        CHECK (confidence >= 0 AND confidence <= 100),
    recommendations JSONB NOT NULL DEFAULT '[]'::JSONB,
    evidence JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. REMEDIATION PLAYBOOKS
CREATE TABLE IF NOT EXISTS public.playbooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    action_type TEXT NOT NULL,
    configuration JSONB NOT NULL DEFAULT '{}'::JSONB,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    requires_approval BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. PLAYBOOK EXECUTION RUNS
CREATE TABLE IF NOT EXISTS public.playbook_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    playbook_id UUID NOT NULL REFERENCES public.playbooks(id) ON DELETE RESTRICT,
    incident_id UUID NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
    requested_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending_approval'
        CHECK (status IN ('pending_approval', 'approved', 'running', 'success', 'failed', 'rejected', 'cancelled')),
    approval_required BOOLEAN NOT NULL DEFAULT TRUE,
    request_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    result_payload JSONB NOT NULL DEFAULT '{}'::JSONB,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);

-- 9. RECOVERY VERIFICATION CHECKS
CREATE TABLE IF NOT EXISTS public.recovery_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
    service_id UUID REFERENCES public.services(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'healthy', 'unhealthy', 'failed')),
    check_type TEXT,
    details JSONB NOT NULL DEFAULT '{}'::JSONB,
    checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. POSTMORTEMS
CREATE TABLE IF NOT EXISTS public.postmortems (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL UNIQUE REFERENCES public.incidents(id) ON DELETE CASCADE,
    summary TEXT NOT NULL,
    root_cause TEXT,
    impact TEXT,
    timeline JSONB NOT NULL DEFAULT '[]'::JSONB,
    lessons_learned TEXT,
    action_items JSONB NOT NULL DEFAULT '[]'::JSONB,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. NOTIFICATIONS
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    incident_id UUID REFERENCES public.incidents(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    channel TEXT NOT NULL DEFAULT 'in_app'
        CHECK (channel IN ('in_app', 'push', 'email', 'telegram')),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'sent', 'failed', 'read')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ
);

-- 12. AUDIT LOG
CREATE TABLE IF NOT EXISTS public.audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    resource_type TEXT,
    resource_id UUID,
    details JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- INDEXES
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id
    ON public.device_tokens(user_id);

CREATE INDEX IF NOT EXISTS idx_deployments_service_id
    ON public.deployments(service_id);

CREATE INDEX IF NOT EXISTS idx_deployments_status
    ON public.deployments(status);

CREATE INDEX IF NOT EXISTS idx_incidents_service_id
    ON public.incidents(service_id);

CREATE INDEX IF NOT EXISTS idx_incidents_status
    ON public.incidents(status);

CREATE INDEX IF NOT EXISTS idx_incidents_severity
    ON public.incidents(severity);

CREATE INDEX IF NOT EXISTS idx_incidents_detected_at
    ON public.incidents(detected_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_analyses_incident_id
    ON public.ai_analyses(incident_id);

CREATE INDEX IF NOT EXISTS idx_playbook_runs_incident_id
    ON public.playbook_runs(incident_id);

CREATE INDEX IF NOT EXISTS idx_playbook_runs_status
    ON public.playbook_runs(status);

CREATE INDEX IF NOT EXISTS idx_recovery_checks_incident_id
    ON public.recovery_checks(incident_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id
    ON public.notifications(user_id);

CREATE INDEX IF NOT EXISTS idx_notifications_status
    ON public.notifications(status);

CREATE INDEX IF NOT EXISTS idx_audit_log_created_at
    ON public.audit_log(created_at DESC);

-- =========================================================
-- UPDATED_AT TRIGGER FUNCTION
-- =========================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- =========================================================
-- UPDATED_AT TRIGGERS
-- =========================================================

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_device_tokens_updated_at ON public.device_tokens;
CREATE TRIGGER set_device_tokens_updated_at
    BEFORE UPDATE ON public.device_tokens
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_services_updated_at ON public.services;
CREATE TRIGGER set_services_updated_at
    BEFORE UPDATE ON public.services
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_incidents_updated_at ON public.incidents;
CREATE TRIGGER set_incidents_updated_at
    BEFORE UPDATE ON public.incidents
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_playbooks_updated_at ON public.playbooks;
CREATE TRIGGER set_playbooks_updated_at
    BEFORE UPDATE ON public.playbooks
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS set_postmortems_updated_at ON public.postmortems;
CREATE TRIGGER set_postmortems_updated_at
    BEFORE UPDATE ON public.postmortems
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deployments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playbooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.playbook_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recovery_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.postmortems ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Users can view and update their own profile.
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
CREATE POLICY profiles_select_own
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

DROP POLICY IF EXISTS profiles_update_own ON public.profiles;
CREATE POLICY profiles_update_own
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Users can manage their own device tokens.
DROP POLICY IF EXISTS device_tokens_select_own ON public.device_tokens;
CREATE POLICY device_tokens_select_own
    ON public.device_tokens FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS device_tokens_insert_own ON public.device_tokens;
CREATE POLICY device_tokens_insert_own
    ON public.device_tokens FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS device_tokens_delete_own ON public.device_tokens;
CREATE POLICY device_tokens_delete_own
    ON public.device_tokens FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- Authenticated users can read enabled playbooks.
DROP POLICY IF EXISTS playbooks_select_enabled ON public.playbooks;
CREATE POLICY playbooks_select_enabled
    ON public.playbooks FOR SELECT
    TO authenticated
    USING (enabled = TRUE);

-- =========================================================
-- SAFE STARTER PLAYBOOKS
-- Disabled by default; require approval.
-- =========================================================

INSERT INTO public.playbooks
    (name, description, action_type, configuration, enabled, requires_approval)
VALUES
    (
        'restart_service',
        'Request a controlled service restart.',
        'restart_service',
        '{"approval_required": true}'::JSONB,
        FALSE,
        TRUE
    ),
    (
        'rollback_deployment',
        'Request a rollback to a previous deployment.',
        'rollback_deployment',
        '{"approval_required": true}'::JSONB,
        FALSE,
        TRUE
    ),
    (
        'scale_service',
        'Request a controlled service scaling operation.',
        'scale_service',
        '{"approval_required": true}'::JSONB,
        FALSE,
        TRUE
    )
ON CONFLICT (name) DO NOTHING;
