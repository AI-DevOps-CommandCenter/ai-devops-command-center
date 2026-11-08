-- =============================================================================
-- Migration: audit coverage for direct table writes, and payload redaction
-- Decisions: A7 (approved 2026-11-07). Follow-up from the final review:
--   #1 After A2-Q3/A7 removed client INSERT on audit_logs, actions that do NOT
--      go through the workflow functions were no longer audited: incident
--      create/update, postmortems, playbook and integration administration,
--      and user role changes (the backend wrote those entries itself, and its
--      writes now fail silently). Triggers now write them in the database,
--      in the same transaction (fail closed, A7-Q1), with the actor from the
--      JWT. Incident status changes also go to the timeline.
--   #2 Request/result payloads of runs were stored without redaction.
--      Credential-like keys are now removed at any depth from
--      playbook_runs.request_payload/result_payload and
--      automation_runs.input/output, for every writer.
-- Rollback:  database/rollback/20261107000800_audit_coverage_and_redaction.down.sql
--
-- Scope of the audit triggers: changes made through the API (a JWT is
-- present). Owner maintenance in the SQL Editor or migrations has no JWT and
-- is recorded by the migration log, not here.
-- Existing rows are not modified.
-- =============================================================================

-- 1. Recursive redaction (#2) ------------------------------------------------------
CREATE FUNCTION public.redact_json(p_value jsonb) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO ''
    AS $$
BEGIN
    IF p_value IS NULL THEN
        RETURN NULL;
    ELSIF jsonb_typeof(p_value) = 'object' THEN
        RETURN coalesce(
            (SELECT jsonb_object_agg(e.key, public.redact_json(e.value))
             FROM jsonb_each(p_value) AS e
             WHERE e.key !~* '(password|passwd|secret|token|api[_-]?key|authorization|credential|private[_-]?key)'),
            '{}'::jsonb);
    ELSIF jsonb_typeof(p_value) = 'array' THEN
        RETURN coalesce(
            (SELECT jsonb_agg(public.redact_json(a.value) ORDER BY a.ord)
             FROM jsonb_array_elements(p_value) WITH ORDINALITY AS a(value, ord)),
            '[]'::jsonb);
    END IF;
    RETURN p_value;
END;
$$;

-- Same signature and contract as in 000500, now recursive.
CREATE OR REPLACE FUNCTION public.redact_sensitive(p_details jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    SET search_path TO ''
    AS $$
    SELECT CASE
        WHEN p_details IS NULL THEN '{}'::jsonb
        WHEN jsonb_typeof(p_details) <> 'object' THEN jsonb_build_object('value', public.redact_json(p_details))
        ELSE public.redact_json(p_details)
    END;
$$;

CREATE FUNCTION public.redact_run_payloads() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
    IF TG_TABLE_NAME = 'playbook_runs' THEN
        NEW.request_payload := public.redact_json(NEW.request_payload);
        NEW.result_payload := public.redact_json(NEW.result_payload);
    ELSE
        NEW.input := public.redact_json(NEW.input);
        NEW.output := public.redact_json(NEW.output);
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER playbook_runs_redact_payloads
    BEFORE INSERT OR UPDATE OF request_payload, result_payload ON public.playbook_runs
    FOR EACH ROW EXECUTE FUNCTION public.redact_run_payloads();
CREATE TRIGGER automation_runs_redact_payloads
    BEFORE INSERT OR UPDATE OF input, output ON public.automation_runs
    FOR EACH ROW EXECUTE FUNCTION public.redact_run_payloads();

-- 2. Audit of direct writes (#1) ---------------------------------------------------
-- TG_ARGV[0] = entity type, TG_ARGV[1] = action prefix.
-- Details: the names of changed columns, plus old/new values of a short list
-- of non-sensitive fields (never settings, descriptions or free text).
CREATE FUNCTION public.audit_row_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_safe constant text[] := ARRAY['status', 'severity', 'title', 'name', 'action_type', 'enabled',
                                    'requires_approval', 'provider', 'is_active', 'role',
                                    'environment', 'service_name', 'incident_id'];
    v_old jsonb;
    v_new jsonb;
    v_id uuid;
    v_changed text[];
    v_details jsonb;
BEGIN
    IF (SELECT auth.uid()) IS NULL THEN
        RETURN NULL;  -- owner maintenance, not an API action
    END IF;

    IF TG_OP = 'INSERT' THEN
        v_new := to_jsonb(NEW);
        v_id := NEW.id;
    ELSIF TG_OP = 'UPDATE' THEN
        v_old := to_jsonb(OLD);
        v_new := to_jsonb(NEW);
        v_id := NEW.id;
        SELECT array_agg(n.key ORDER BY n.key) INTO v_changed
        FROM jsonb_each(v_new) AS n
        WHERE n.key <> 'updated_at' AND n.value IS DISTINCT FROM (v_old -> n.key);
        IF v_changed IS NULL THEN
            RETURN NULL;  -- nothing but updated_at changed
        END IF;
    ELSE
        v_old := to_jsonb(OLD);
        v_id := OLD.id;
    END IF;

    v_details := jsonb_build_object('changed', to_jsonb(v_changed))
        || coalesce((SELECT jsonb_object_agg('old_' || o.key, o.value) FROM jsonb_each(v_old) AS o
                     WHERE o.key = ANY (v_safe) AND (TG_OP = 'DELETE' OR o.key = ANY (v_changed))), '{}'::jsonb)
        || coalesce((SELECT jsonb_object_agg(n.key, n.value) FROM jsonb_each(v_new) AS n
                     WHERE n.key = ANY (v_safe) AND (TG_OP = 'INSERT' OR n.key = ANY (v_changed))), '{}'::jsonb);

    PERFORM public.log_audit_event(
        TG_ARGV[1] || CASE TG_OP WHEN 'INSERT' THEN '_CREATED' WHEN 'UPDATE' THEN '_UPDATED' ELSE '_DELETED' END,
        TG_ARGV[0], v_id, v_details);

    RETURN NULL;
END;
$$;

CREATE TRIGGER audit_incidents
    AFTER INSERT OR UPDATE ON public.incidents
    FOR EACH ROW EXECUTE FUNCTION public.audit_row_change('incident', 'INCIDENT');
CREATE TRIGGER audit_postmortems
    AFTER INSERT OR UPDATE ON public.postmortems
    FOR EACH ROW EXECUTE FUNCTION public.audit_row_change('postmortem', 'POSTMORTEM');
CREATE TRIGGER audit_playbooks
    AFTER INSERT OR UPDATE OR DELETE ON public.playbooks
    FOR EACH ROW EXECUTE FUNCTION public.audit_row_change('playbook', 'PLAYBOOK');
CREATE TRIGGER audit_integrations
    AFTER INSERT OR UPDATE OR DELETE ON public.integrations
    FOR EACH ROW EXECUTE FUNCTION public.audit_row_change('integration', 'INTEGRATION');
-- Role changes (admin_update_user_role keeps the caller's JWT, so the admin is the actor).
CREATE TRIGGER audit_profile_role
    AFTER UPDATE OF role ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.audit_row_change('profile', 'USER_ROLE');

-- 3. Incident status changes on the timeline (A7) ------------------------------------
CREATE FUNCTION public.incident_status_event() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
    IF (SELECT auth.uid()) IS NOT NULL THEN
        PERFORM public.write_incident_event(NEW.id, 'status_change',
            format('Status %s -> %s', OLD.status, NEW.status),
            jsonb_build_object('from', OLD.status, 'to', NEW.status));
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER incidents_status_event
    AFTER UPDATE OF status ON public.incidents
    FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION public.incident_status_event();

-- 4. Privileges ---------------------------------------------------------------------
REVOKE ALL ON FUNCTION
    public.redact_json(jsonb),
    public.redact_run_payloads(),
    public.audit_row_change(),
    public.incident_status_event()
FROM PUBLIC, anon, authenticated;
