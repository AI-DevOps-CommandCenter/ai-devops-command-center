-- =============================================================================
-- Migration: baseline of the verified live `public` schema
-- Project:   AI-Powered Mobile DevOps Command Center
-- Status:    VERIFIED CURRENT STATE. No new objects, no data.
--
-- Sources (all read-only, recorded 2026-11-07):
--   [V-SCHEMA]  database-backups/public-schema.sql (structure-only export of
--               live `public`): 18 tables, 22 constraints, 29 FKs, 27 indexes,
--               31 policies, 6 functions, 6 triggers, RLS on 18 tables.
--               Cross-checked against the backup archive's object list
--               (definitions only, no table data): identical counts.
--   [V-LIVE]    Grants: checklist P3 (tables) and P3c (functions).
--   [V-BACKUP]  Database-level objects missing from the export, taken from the
--               backup archive's object definitions (no table data read):
--               event trigger `ensure_rls`; trigger `on_auth_user_created`.
--
-- Transformation of the export (mechanical, no object changed):
--   * removed psql meta-commands (\restrict / \unrestrict): not SQL;
--   * removed session SET statements and the search_path set_config call
--     (every object name in the export is schema-qualified);
--   * kept `check_function_bodies = false` for this migration only, because
--     the export creates functions before the tables they reference.
--
-- NOT included (intentionally):
--   * Supabase platform-managed objects (auth/storage/realtime schemas,
--     extensions, supabase_admin event triggers): provided by Supabase itself.
--   * Live default privileges (P3b): an environment setting. Every later
--     migration grants/revokes explicitly instead of relying on defaults.
--   * service_role grants: not recorded by P3/P3c [UNKNOWN]; left to the
--     platform default. The backend never uses service_role (D-001).
--   * Data. Production data is never part of migrations (D-007).
--
-- Production: this baseline must NOT be executed on production (the objects
-- already exist). It is marked as applied there in a separately approved step.
-- =============================================================================

SET check_function_bodies = false;

--
-- PostgreSQL database dump
--


-- Dumped from database version 17.11
-- Dumped by pg_dump version 18.6


--
-- Name: admin_update_user_role(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_update_user_role(target_user_id uuid, new_role text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
    -- Ensure a user is authenticated
    IF (SELECT auth.uid()) IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    -- Only admins can change roles
    IF NOT (SELECT public.is_admin()) THEN
        RAISE EXCEPTION 'Only admins can change user roles';
    END IF;

    -- Prevent admins from changing their own role
    IF target_user_id = (SELECT auth.uid()) THEN
        RAISE EXCEPTION 'You cannot change your own role';
    END IF;

    -- Validate the requested role
    IF new_role NOT IN ('user', 'admin', 'operator') THEN
        RAISE EXCEPTION 'Invalid role';
    END IF;

    -- Update the target user's role
    UPDATE public.profiles
    SET
        role = new_role,
        updated_at = now()
    WHERE id = target_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User profile not found';
    END IF;
END;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data ->> 'full_name'
    );

    RETURN NEW;
END;
$$;


--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = (SELECT auth.uid())
        AND role = 'admin'
    );
$$;


--
-- Name: is_incident_manager(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_incident_manager() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO ''
    AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = (SELECT auth.uid())
          AND role IN ('admin', 'operator')
    );
$$;


--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
  tbl name;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        SELECT c.relname INTO tbl FROM pg_catalog.pg_class c WHERE c.oid = cmd.objid;
        EXECUTE format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;




--
-- Name: ai_analyses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_analyses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    incident_id uuid NOT NULL,
    model_name text,
    summary text,
    root_cause text,
    confidence numeric(5,2),
    recommendations jsonb DEFAULT '[]'::jsonb NOT NULL,
    evidence jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    severity text,
    recommended_action text,
    CONSTRAINT ai_analyses_action_allowed CHECK (((recommended_action IS NULL) OR (recommended_action = ANY (ARRAY['restart'::text, 'rollback'::text, 'scale'::text, 'circuit_breaker'::text])))),
    CONSTRAINT ai_analyses_confidence_range CHECK (((confidence IS NULL) OR ((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)))),
    CONSTRAINT ai_analyses_severity_allowed CHECK (((severity IS NULL) OR (severity = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text]))))
);


--
-- Name: approvals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approvals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    incident_id uuid NOT NULL,
    requested_by uuid,
    approver_id uuid,
    status text DEFAULT 'pending'::text NOT NULL,
    comments text,
    requested_at timestamp with time zone DEFAULT now(),
    decided_at timestamp with time zone,
    CONSTRAINT approvals_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])))
);


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    action text NOT NULL,
    resource_type text,
    resource_id uuid,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    entity_type text,
    entity_id uuid,
    details jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: deployments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deployments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_id uuid,
    provider text,
    repository text,
    branch text,
    commit_sha text,
    status text DEFAULT 'pending'::text NOT NULL,
    deployed_by uuid,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT deployments_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'running'::text, 'success'::text, 'failed'::text, 'cancelled'::text])))
);


--
-- Name: device_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.device_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_token text NOT NULL,
    platform text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT device_tokens_platform_check CHECK ((platform = ANY (ARRAY['android'::text, 'ios'::text, 'web'::text])))
);


--
-- Name: incident_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.incident_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    incident_id uuid NOT NULL,
    source text,
    log_level text DEFAULT 'info'::text,
    message text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    logged_at timestamp with time zone DEFAULT now(),
    CONSTRAINT incident_logs_log_level_check CHECK ((log_level = ANY (ARRAY['info'::text, 'warning'::text, 'error'::text, 'critical'::text])))
);


--
-- Name: incidents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.incidents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service_id uuid,
    deployment_id uuid,
    title text NOT NULL,
    description text,
    severity text DEFAULT 'medium'::text NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    source text,
    detected_at timestamp with time zone DEFAULT now() NOT NULL,
    acknowledged_at timestamp with time zone,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    environment text,
    service_name text,
    CONSTRAINT incidents_severity_check CHECK ((severity = ANY (ARRAY['critical'::text, 'high'::text, 'medium'::text, 'low'::text, 'info'::text]))),
    CONSTRAINT incidents_status_check CHECK ((status = ANY (ARRAY['open'::text, 'investigating'::text, 'identified'::text, 'mitigating'::text, 'resolved'::text, 'closed'::text])))
);


--
-- Name: integrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.integrations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    provider text NOT NULL,
    is_active boolean DEFAULT true,
    settings jsonb DEFAULT '{}'::jsonb,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: investigations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.investigations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    incident_id uuid NOT NULL,
    status text DEFAULT 'pending'::text,
    summary text,
    root_cause text,
    evidence jsonb DEFAULT '[]'::jsonb,
    ai_model text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT investigations_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'running'::text, 'completed'::text, 'failed'::text])))
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    incident_id uuid,
    title text NOT NULL,
    message text NOT NULL,
    channel text DEFAULT 'in_app'::text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    read_at timestamp with time zone,
    CONSTRAINT notifications_channel_check CHECK ((channel = ANY (ARRAY['in_app'::text, 'push'::text, 'email'::text, 'telegram'::text]))),
    CONSTRAINT notifications_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'sent'::text, 'failed'::text, 'read'::text])))
);


--
-- Name: playbook_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.playbook_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    playbook_id uuid NOT NULL,
    incident_id uuid NOT NULL,
    requested_by uuid,
    approved_by uuid,
    status text DEFAULT 'pending_approval'::text NOT NULL,
    approval_required boolean DEFAULT true NOT NULL,
    request_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    result_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    requested_at timestamp with time zone DEFAULT now() NOT NULL,
    approved_at timestamp with time zone,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    CONSTRAINT playbook_runs_status_check CHECK ((status = ANY (ARRAY['pending_approval'::text, 'approved'::text, 'running'::text, 'success'::text, 'failed'::text, 'rejected'::text, 'cancelled'::text])))
);


--
-- Name: playbooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.playbooks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    action_type text NOT NULL,
    configuration jsonb DEFAULT '{}'::jsonb NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    requires_approval boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT playbooks_action_type_allowed CHECK ((action_type = ANY (ARRAY['restart'::text, 'rollback'::text, 'scale'::text, 'circuit_breaker'::text])))
);


--
-- Name: postmortems; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.postmortems (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    incident_id uuid NOT NULL,
    summary text NOT NULL,
    root_cause text,
    impact text,
    timeline jsonb DEFAULT '[]'::jsonb NOT NULL,
    lessons_learned text,
    action_items jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text,
    email text,
    role text DEFAULT 'user'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT profiles_role_check CHECK ((role = ANY (ARRAY['user'::text, 'admin'::text, 'operator'::text])))
);


--
-- Name: recovery_checks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recovery_checks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    incident_id uuid NOT NULL,
    service_id uuid,
    status text DEFAULT 'pending'::text NOT NULL,
    check_type text,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    checked_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT recovery_checks_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'healthy'::text, 'unhealthy'::text, 'failed'::text])))
);


--
-- Name: remediation_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.remediation_executions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    incident_id uuid NOT NULL,
    playbook_id uuid,
    triggered_by uuid,
    status text DEFAULT 'pending'::text NOT NULL,
    input_data jsonb DEFAULT '{}'::jsonb,
    output_data jsonb DEFAULT '{}'::jsonb,
    started_at timestamp with time zone,
    completed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT remediation_executions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'running'::text, 'succeeded'::text, 'failed'::text, 'cancelled'::text])))
);


--
-- Name: services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.services (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    environment text DEFAULT 'development'::text NOT NULL,
    endpoint text,
    status text DEFAULT 'unknown'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT services_status_check CHECK ((status = ANY (ARRAY['healthy'::text, 'degraded'::text, 'down'::text, 'unknown'::text])))
);


--
-- Name: ai_analyses ai_analyses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_analyses
    ADD CONSTRAINT ai_analyses_pkey PRIMARY KEY (id);


--
-- Name: approvals approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: deployments deployments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deployments
    ADD CONSTRAINT deployments_pkey PRIMARY KEY (id);


--
-- Name: device_tokens device_tokens_device_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT device_tokens_device_token_key UNIQUE (device_token);


--
-- Name: device_tokens device_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT device_tokens_pkey PRIMARY KEY (id);


--
-- Name: incident_logs incident_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident_logs
    ADD CONSTRAINT incident_logs_pkey PRIMARY KEY (id);


--
-- Name: incidents incidents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_pkey PRIMARY KEY (id);


--
-- Name: integrations integrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integrations
    ADD CONSTRAINT integrations_pkey PRIMARY KEY (id);


--
-- Name: investigations investigations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investigations
    ADD CONSTRAINT investigations_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: playbook_runs playbook_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playbook_runs
    ADD CONSTRAINT playbook_runs_pkey PRIMARY KEY (id);


--
-- Name: playbooks playbooks_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playbooks
    ADD CONSTRAINT playbooks_name_key UNIQUE (name);


--
-- Name: playbooks playbooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playbooks
    ADD CONSTRAINT playbooks_pkey PRIMARY KEY (id);


--
-- Name: postmortems postmortems_incident_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postmortems
    ADD CONSTRAINT postmortems_incident_id_key UNIQUE (incident_id);


--
-- Name: postmortems postmortems_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postmortems
    ADD CONSTRAINT postmortems_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_email_key UNIQUE (email);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: recovery_checks recovery_checks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recovery_checks
    ADD CONSTRAINT recovery_checks_pkey PRIMARY KEY (id);


--
-- Name: remediation_executions remediation_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remediation_executions
    ADD CONSTRAINT remediation_executions_pkey PRIMARY KEY (id);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (id);


--
-- Name: idx_ai_analyses_incident_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_analyses_incident_id ON public.ai_analyses USING btree (incident_id);


--
-- Name: idx_approvals_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_approvals_status ON public.approvals USING btree (status);


--
-- Name: idx_audit_log_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_created_at ON public.audit_log USING btree (created_at DESC);


--
-- Name: idx_audit_log_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_log_user_id ON public.audit_log USING btree (user_id);


--
-- Name: idx_deployments_deployed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deployments_deployed_by ON public.deployments USING btree (deployed_by);


--
-- Name: idx_deployments_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deployments_service_id ON public.deployments USING btree (service_id);


--
-- Name: idx_deployments_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deployments_status ON public.deployments USING btree (status);


--
-- Name: idx_device_tokens_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_device_tokens_user_id ON public.device_tokens USING btree (user_id);


--
-- Name: idx_incident_logs_incident; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incident_logs_incident ON public.incident_logs USING btree (incident_id);


--
-- Name: idx_incidents_deployment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_deployment_id ON public.incidents USING btree (deployment_id);


--
-- Name: idx_incidents_detected_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_detected_at ON public.incidents USING btree (detected_at DESC);


--
-- Name: idx_incidents_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_service_id ON public.incidents USING btree (service_id);


--
-- Name: idx_incidents_severity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_severity ON public.incidents USING btree (severity);


--
-- Name: idx_incidents_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_incidents_status ON public.incidents USING btree (status);


--
-- Name: idx_investigations_incident; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_investigations_incident ON public.investigations USING btree (incident_id);


--
-- Name: idx_notifications_incident_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_incident_id ON public.notifications USING btree (incident_id);


--
-- Name: idx_notifications_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_status ON public.notifications USING btree (status);


--
-- Name: idx_notifications_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user_id ON public.notifications USING btree (user_id);


--
-- Name: idx_playbook_runs_approved_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_playbook_runs_approved_by ON public.playbook_runs USING btree (approved_by);


--
-- Name: idx_playbook_runs_incident_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_playbook_runs_incident_id ON public.playbook_runs USING btree (incident_id);


--
-- Name: idx_playbook_runs_playbook_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_playbook_runs_playbook_id ON public.playbook_runs USING btree (playbook_id);


--
-- Name: idx_playbook_runs_requested_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_playbook_runs_requested_by ON public.playbook_runs USING btree (requested_by);


--
-- Name: idx_playbook_runs_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_playbook_runs_status ON public.playbook_runs USING btree (status);


--
-- Name: idx_postmortems_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_postmortems_created_by ON public.postmortems USING btree (created_by);


--
-- Name: idx_recovery_checks_incident_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recovery_checks_incident_id ON public.recovery_checks USING btree (incident_id);


--
-- Name: idx_recovery_checks_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_recovery_checks_service_id ON public.recovery_checks USING btree (service_id);


--
-- Name: idx_remediation_incident; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_remediation_incident ON public.remediation_executions USING btree (incident_id);


--
-- Name: device_tokens set_device_tokens_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_device_tokens_updated_at BEFORE UPDATE ON public.device_tokens FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: incidents set_incidents_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_incidents_updated_at BEFORE UPDATE ON public.incidents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: playbooks set_playbooks_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_playbooks_updated_at BEFORE UPDATE ON public.playbooks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: postmortems set_postmortems_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_postmortems_updated_at BEFORE UPDATE ON public.postmortems FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: profiles set_profiles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: services set_services_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER set_services_updated_at BEFORE UPDATE ON public.services FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ai_analyses ai_analyses_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_analyses
    ADD CONSTRAINT ai_analyses_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: approvals approvals_approver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT approvals_approver_id_fkey FOREIGN KEY (approver_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: approvals approvals_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT approvals_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: approvals approvals_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approvals
    ADD CONSTRAINT approvals_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: audit_log audit_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: audit_logs audit_logs_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: deployments deployments_deployed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deployments
    ADD CONSTRAINT deployments_deployed_by_fkey FOREIGN KEY (deployed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: deployments deployments_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deployments
    ADD CONSTRAINT deployments_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id) ON DELETE SET NULL;


--
-- Name: device_tokens device_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.device_tokens
    ADD CONSTRAINT device_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: incident_logs incident_logs_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incident_logs
    ADD CONSTRAINT incident_logs_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: incidents incidents_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: incidents incidents_deployment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_deployment_id_fkey FOREIGN KEY (deployment_id) REFERENCES public.deployments(id) ON DELETE SET NULL;


--
-- Name: incidents incidents_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.incidents
    ADD CONSTRAINT incidents_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id) ON DELETE SET NULL;


--
-- Name: integrations integrations_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.integrations
    ADD CONSTRAINT integrations_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: investigations investigations_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.investigations
    ADD CONSTRAINT investigations_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: playbook_runs playbook_runs_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playbook_runs
    ADD CONSTRAINT playbook_runs_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: playbook_runs playbook_runs_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playbook_runs
    ADD CONSTRAINT playbook_runs_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: playbook_runs playbook_runs_playbook_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playbook_runs
    ADD CONSTRAINT playbook_runs_playbook_id_fkey FOREIGN KEY (playbook_id) REFERENCES public.playbooks(id) ON DELETE RESTRICT;


--
-- Name: playbook_runs playbook_runs_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.playbook_runs
    ADD CONSTRAINT playbook_runs_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: postmortems postmortems_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postmortems
    ADD CONSTRAINT postmortems_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: postmortems postmortems_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postmortems
    ADD CONSTRAINT postmortems_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: recovery_checks recovery_checks_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recovery_checks
    ADD CONSTRAINT recovery_checks_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: recovery_checks recovery_checks_service_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recovery_checks
    ADD CONSTRAINT recovery_checks_service_id_fkey FOREIGN KEY (service_id) REFERENCES public.services(id) ON DELETE SET NULL;


--
-- Name: remediation_executions remediation_executions_incident_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remediation_executions
    ADD CONSTRAINT remediation_executions_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id) ON DELETE CASCADE;


--
-- Name: remediation_executions remediation_executions_playbook_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remediation_executions
    ADD CONSTRAINT remediation_executions_playbook_id_fkey FOREIGN KEY (playbook_id) REFERENCES public.playbooks(id) ON DELETE SET NULL;


--
-- Name: remediation_executions remediation_executions_triggered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.remediation_executions
    ADD CONSTRAINT remediation_executions_triggered_by_fkey FOREIGN KEY (triggered_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: remediation_executions Admins and operators create executions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins and operators create executions" ON public.remediation_executions FOR INSERT TO authenticated WITH CHECK (( SELECT public.is_incident_manager() AS is_incident_manager));


--
-- Name: postmortems Admins and operators create postmortems; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins and operators create postmortems" ON public.postmortems FOR INSERT TO authenticated WITH CHECK (( SELECT public.is_incident_manager() AS is_incident_manager));


--
-- Name: remediation_executions Admins and operators update executions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins and operators update executions" ON public.remediation_executions FOR UPDATE TO authenticated USING (( SELECT public.is_incident_manager() AS is_incident_manager)) WITH CHECK (( SELECT public.is_incident_manager() AS is_incident_manager));


--
-- Name: incidents Admins and operators update incidents; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins and operators update incidents" ON public.incidents FOR UPDATE TO authenticated USING (( SELECT public.is_incident_manager() AS is_incident_manager)) WITH CHECK (( SELECT public.is_incident_manager() AS is_incident_manager));


--
-- Name: investigations Admins and operators update investigations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins and operators update investigations" ON public.investigations FOR UPDATE TO authenticated USING (( SELECT public.is_incident_manager() AS is_incident_manager)) WITH CHECK (( SELECT public.is_incident_manager() AS is_incident_manager));


--
-- Name: playbook_runs Admins and operators update playbook runs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins and operators update playbook runs" ON public.playbook_runs FOR UPDATE TO authenticated USING (( SELECT public.is_incident_manager() AS is_incident_manager)) WITH CHECK ((( SELECT public.is_incident_manager() AS is_incident_manager) AND ((approved_by IS NULL) OR (approved_by <> requested_by))));


--
-- Name: postmortems Admins and operators update postmortems; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins and operators update postmortems" ON public.postmortems FOR UPDATE TO authenticated USING (( SELECT public.is_incident_manager() AS is_incident_manager)) WITH CHECK (( SELECT public.is_incident_manager() AS is_incident_manager));


--
-- Name: approvals Admins decide approval requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins decide approval requests" ON public.approvals FOR UPDATE TO authenticated USING ((( SELECT public.is_admin() AS is_admin) AND (requested_by <> ( SELECT auth.uid() AS uid)) AND (status = 'pending'::text))) WITH CHECK ((( SELECT public.is_admin() AS is_admin) AND (requested_by <> ( SELECT auth.uid() AS uid)) AND (status = ANY (ARRAY['approved'::text, 'rejected'::text])) AND (approver_id = ( SELECT auth.uid() AS uid))));


--
-- Name: integrations Admins manage integrations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage integrations" ON public.integrations TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: playbooks Admins manage playbooks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage playbooks" ON public.playbooks TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: audit_logs Admins view audit logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins view audit logs" ON public.audit_logs FOR SELECT TO authenticated USING (public.is_admin());


--
-- Name: investigations Users create investigations for own incidents or managers creat; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users create investigations for own incidents or managers creat" ON public.investigations FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.incidents i
  WHERE ((i.id = investigations.incident_id) AND ((i.created_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_incident_manager() AS is_incident_manager))))));


--
-- Name: incident_logs Users create logs for own incidents or managers create all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users create logs for own incidents or managers create all" ON public.incident_logs FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.incidents i
  WHERE ((i.id = incident_logs.incident_id) AND ((i.created_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_incident_manager() AS is_incident_manager))))));


--
-- Name: approvals Users create own approval requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users create own approval requests" ON public.approvals FOR INSERT TO authenticated WITH CHECK ((requested_by = ( SELECT auth.uid() AS uid)));


--
-- Name: incidents Users create own incidents; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users create own incidents" ON public.incidents FOR INSERT TO authenticated WITH CHECK ((created_by = ( SELECT auth.uid() AS uid)));


--
-- Name: playbook_runs Users create own playbook requests or managers create all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users create own playbook requests or managers create all" ON public.playbook_runs FOR INSERT TO authenticated WITH CHECK (((requested_by = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM public.incidents i
  WHERE ((i.id = playbook_runs.incident_id) AND ((i.created_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_incident_manager() AS is_incident_manager)))))));


--
-- Name: audit_logs Users insert own audit logs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users insert own audit logs" ON public.audit_logs FOR INSERT TO authenticated WITH CHECK ((actor_id = ( SELECT auth.uid() AS uid)));


--
-- Name: approvals Users view own approvals or admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users view own approvals or admin" ON public.approvals FOR SELECT TO authenticated USING (((requested_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_admin() AS is_admin)));


--
-- Name: remediation_executions Users view own executions or managers view all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users view own executions or managers view all" ON public.remediation_executions FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.incidents i
  WHERE ((i.id = remediation_executions.incident_id) AND ((i.created_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_incident_manager() AS is_incident_manager))))));


--
-- Name: incident_logs Users view own incident logs or managers view all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users view own incident logs or managers view all" ON public.incident_logs FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.incidents i
  WHERE ((i.id = incident_logs.incident_id) AND ((i.created_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_incident_manager() AS is_incident_manager))))));


--
-- Name: incidents Users view own incidents or managers view all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users view own incidents or managers view all" ON public.incidents FOR SELECT TO authenticated USING (((created_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_incident_manager() AS is_incident_manager)));


--
-- Name: investigations Users view own investigations or managers view all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users view own investigations or managers view all" ON public.investigations FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.incidents i
  WHERE ((i.id = investigations.incident_id) AND ((i.created_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_incident_manager() AS is_incident_manager))))));


--
-- Name: playbook_runs Users view own playbook runs or managers view all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users view own playbook runs or managers view all" ON public.playbook_runs FOR SELECT TO authenticated USING (((requested_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_incident_manager() AS is_incident_manager)));


--
-- Name: postmortems Users view own postmortems or managers view all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users view own postmortems or managers view all" ON public.postmortems FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.incidents i
  WHERE ((i.id = postmortems.incident_id) AND ((i.created_by = ( SELECT auth.uid() AS uid)) OR ( SELECT public.is_incident_manager() AS is_incident_manager))))));


--
-- Name: profiles View own profile or admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "View own profile or admin" ON public.profiles FOR SELECT TO authenticated USING (((id = ( SELECT auth.uid() AS uid)) OR public.is_admin()));


--
-- Name: ai_analyses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_analyses ENABLE ROW LEVEL SECURITY;

--
-- Name: approvals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.approvals ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: deployments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deployments ENABLE ROW LEVEL SECURITY;

--
-- Name: device_tokens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: device_tokens device_tokens_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY device_tokens_delete_own ON public.device_tokens FOR DELETE TO authenticated USING ((user_id = auth.uid()));


--
-- Name: device_tokens device_tokens_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY device_tokens_insert_own ON public.device_tokens FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));


--
-- Name: device_tokens device_tokens_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY device_tokens_select_own ON public.device_tokens FOR SELECT TO authenticated USING ((user_id = auth.uid()));


--
-- Name: incident_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.incident_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: incidents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;

--
-- Name: integrations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.integrations ENABLE ROW LEVEL SECURITY;

--
-- Name: investigations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.investigations ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: playbook_runs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.playbook_runs ENABLE ROW LEVEL SECURITY;

--
-- Name: playbooks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.playbooks ENABLE ROW LEVEL SECURITY;

--
-- Name: playbooks playbooks_select_enabled; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY playbooks_select_enabled ON public.playbooks FOR SELECT TO authenticated USING ((enabled = true));


--
-- Name: postmortems; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.postmortems ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_select_own ON public.profiles FOR SELECT TO authenticated USING ((auth.uid() = id));


--
-- Name: profiles profiles_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_update_own ON public.profiles FOR UPDATE TO authenticated USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));


--
-- Name: recovery_checks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.recovery_checks ENABLE ROW LEVEL SECURITY;

--
-- Name: remediation_executions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.remediation_executions ENABLE ROW LEVEL SECURITY;

--
-- Name: services; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--



RESET check_function_bodies;

-- =============================================================================
-- Database-level objects not contained in the `public` export  [V-BACKUP]
-- =============================================================================

-- Creates a profile row for every new Supabase Auth user (role defaults to
-- 'user' via the profiles.role column default).
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Enables RLS automatically on every new table created in `public`.
CREATE EVENT TRIGGER ensure_rls ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
    EXECUTE FUNCTION public.rls_auto_enable();

-- =============================================================================
-- Table privileges for client roles  [V-LIVE, checklist P3, 2026-11-07]
-- Reset first so the result does not depend on the environment's defaults.
-- RLS policies (above) still decide which rows a role can see or change.
-- =============================================================================

REVOKE ALL ON TABLE
    public.ai_analyses, public.approvals, public.audit_log, public.audit_logs,
    public.deployments, public.device_tokens, public.incident_logs,
    public.incidents, public.integrations, public.investigations,
    public.notifications, public.playbook_runs, public.playbooks,
    public.postmortems, public.profiles, public.recovery_checks,
    public.remediation_executions, public.services
FROM PUBLIC, anon, authenticated;

GRANT SELECT, INSERT, UPDATE         ON TABLE public.approvals              TO authenticated;
GRANT SELECT, INSERT                 ON TABLE public.audit_logs             TO authenticated;
GRANT SELECT, INSERT                 ON TABLE public.incident_logs          TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON TABLE public.incidents              TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.integrations           TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON TABLE public.investigations         TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON TABLE public.playbook_runs          TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.playbooks              TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON TABLE public.postmortems            TO authenticated;
GRANT SELECT                         ON TABLE public.profiles               TO authenticated;
GRANT SELECT, INSERT, UPDATE         ON TABLE public.remediation_executions TO authenticated;
-- No client grants (verified): ai_analyses, audit_log, deployments,
-- device_tokens, notifications, recovery_checks, services. anon: none.

-- =============================================================================
-- Function privileges  [V-LIVE, checklist P3c, 2026-11-07]
-- =============================================================================

REVOKE ALL ON FUNCTION
    public.admin_update_user_role(uuid, text),
    public.handle_new_user(),
    public.is_admin(),
    public.is_incident_manager(),
    public.rls_auto_enable(),
    public.set_updated_at()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.admin_update_user_role(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user()                  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin()                         TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_incident_manager()              TO authenticated;
GRANT EXECUTE ON FUNCTION public.rls_auto_enable()                  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_updated_at()                   TO anon, authenticated;
