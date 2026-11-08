-- =============================================================================
-- Migration: trusted, append-only audit log and incident timeline
-- Decision:  A7 (approved 2026-11-07): append-only audit with database-enforced
--            protections; actor taken from the authenticated context; no client
--            updates/deletes; critical operations and their audit entry commit
--            atomically (fail closed, A7-Q1); incident_events kept separate for
--            the timeline (A7-Q6). No back-fill of past history (A7-Q4).
--            A7-Q3 (2026-11-07): remove the actor FK, keep the actor id.
-- Rollback:  database/rollback/20261107000500_trusted_audit_and_timeline.down.sql
--
-- What this changes:
--   * audit_logs / incident_events: UPDATE, DELETE and TRUNCATE are blocked by
--     triggers for EVERY role, including the table owner and service_role.
--   * The actor columns no longer reference profiles. Deleting a user keeps
--     their history unchanged (an FK with ON DELETE SET NULL would rewrite it).
--   * Clients can no longer INSERT audit entries (A2-Q3). Entries are written
--     only by log_audit_event(), inside the workflow functions.
--   * Incident timeline readable by whoever can read the incident.
--
-- Existing rows are not modified.
-- =============================================================================

-- 1. Actor references without FK (A7-Q3) -------------------------------------------
ALTER TABLE public.audit_logs DROP CONSTRAINT audit_logs_actor_id_fkey;
ALTER TABLE public.incident_events DROP CONSTRAINT incident_events_actor_id_fkey;

COMMENT ON COLUMN public.audit_logs.actor_id IS
    'auth.uid() of the actor at the time of the action. No FK on purpose (A7-Q3): history survives profile deletion.';
COMMENT ON COLUMN public.incident_events.actor_id IS
    'auth.uid() of the actor at the time of the event. No FK on purpose (A7-Q3).';

-- 2. Append-only guards (all roles) -------------------------------------------------
CREATE FUNCTION public.prevent_history_change() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO ''
    AS $$
BEGIN
    RAISE EXCEPTION '% is append-only: % is not allowed.', TG_TABLE_NAME, TG_OP
        USING ERRCODE = 'DC403';
END;
$$;

CREATE TRIGGER audit_logs_append_only
    BEFORE UPDATE OR DELETE ON public.audit_logs
    FOR EACH ROW EXECUTE FUNCTION public.prevent_history_change();
CREATE TRIGGER audit_logs_no_truncate
    BEFORE TRUNCATE ON public.audit_logs
    FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_history_change();

CREATE TRIGGER incident_events_append_only
    BEFORE UPDATE OR DELETE ON public.incident_events
    FOR EACH ROW EXECUTE FUNCTION public.prevent_history_change();
CREATE TRIGGER incident_events_no_truncate
    BEFORE TRUNCATE ON public.incident_events
    FOR EACH STATEMENT EXECUTE FUNCTION public.prevent_history_change();

-- 3. Trusted writers (INTERNAL: no client EXECUTE) ------------------------------------

-- Removes top-level keys that look like credentials, so they never reach history.
CREATE FUNCTION public.redact_sensitive(p_details jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    SET search_path TO ''
    AS $$
    SELECT CASE
        WHEN p_details IS NULL THEN '{}'::jsonb
        WHEN jsonb_typeof(p_details) <> 'object' THEN jsonb_build_object('value', p_details)
        ELSE coalesce(
            (SELECT jsonb_object_agg(key, value)
             FROM jsonb_each(p_details)
             WHERE key !~* '(password|passwd|secret|token|api[_-]?key|authorization|credential|private[_-]?key)'),
            '{}'::jsonb)
    END;
$$;

-- Writes one audit entry as the caller. Fails (and so fails the calling action)
-- if the entry cannot be written.
CREATE FUNCTION public.log_audit_event(
    p_action text,
    p_entity_type text,
    p_entity_id uuid,
    p_details jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_id uuid;
    v_details jsonb;
BEGIN
    IF p_action IS NULL OR p_action !~ '^[A-Z][A-Z0-9_]{2,63}$' THEN
        RAISE EXCEPTION 'Invalid audit action.' USING ERRCODE = 'DC422';
    END IF;

    v_details := public.redact_sensitive(p_details)
        || jsonb_build_object('actor_role', coalesce(public.current_app_role(), 'system'));

    IF length(v_details::text) > 8000 THEN
        RAISE EXCEPTION 'Audit details too large.' USING ERRCODE = 'DC422';
    END IF;

    INSERT INTO public.audit_logs (actor_id, action, entity_type, entity_id, details, created_at)
    VALUES ((SELECT auth.uid()), p_action, p_entity_type, p_entity_id, v_details, now())
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

-- Writes one timeline event as the caller.
CREATE FUNCTION public.write_incident_event(
    p_incident_id uuid,
    p_event_type text,
    p_message text,
    p_metadata jsonb DEFAULT '{}'::jsonb,
    p_level text DEFAULT 'info'
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_id uuid;
BEGIN
    IF p_message IS NOT NULL AND length(p_message) > 2000 THEN
        RAISE EXCEPTION 'Timeline message too long.' USING ERRCODE = 'DC422';
    END IF;

    INSERT INTO public.incident_events (incident_id, event_type, source, level, message, metadata, actor_id)
    VALUES (p_incident_id, p_event_type, coalesce(public.current_app_role(), 'system'), p_level,
            p_message, public.redact_sensitive(p_metadata), (SELECT auth.uid()))
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

-- 4. Public timeline function ---------------------------------------------------------
-- Managers may add comments; the automation identity may add operational events.
-- Approval and status events are written only by the workflow functions.
CREATE FUNCTION public.add_incident_event(
    p_incident_id uuid,
    p_event_type text,
    p_message text,
    p_metadata jsonb DEFAULT '{}'::jsonb,
    p_level text DEFAULT 'info'
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_role text;
BEGIN
    PERFORM public.require_app_role(ARRAY['operator', 'admin', 'automation']);
    v_role := public.current_app_role();

    IF p_message IS NULL OR btrim(p_message) = '' THEN
        RAISE EXCEPTION 'A message is required.' USING ERRCODE = 'DC422';
    END IF;

    IF v_role IN ('operator', 'admin') AND p_event_type IS DISTINCT FROM 'comment' THEN
        RAISE EXCEPTION 'Managers can only add comments to the timeline.' USING ERRCODE = 'DC403';
    END IF;

    IF v_role = 'automation'
       AND p_event_type NOT IN ('log', 'comment', 'investigation', 'remediation', 'recovery', 'notification') THEN
        RAISE EXCEPTION 'Automation cannot add % events.', p_event_type USING ERRCODE = 'DC403';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.incidents WHERE id = p_incident_id) THEN
        RAISE EXCEPTION 'Incident not found.' USING ERRCODE = 'DC404';
    END IF;

    RETURN public.write_incident_event(p_incident_id, p_event_type, p_message, p_metadata, p_level);
END;
$$;

-- 5. Access ----------------------------------------------------------------------------
-- A2-Q3: no direct client audit writes.
REVOKE INSERT ON TABLE public.audit_logs FROM authenticated;

-- Timeline: read-only for whoever can read the incident.
GRANT SELECT ON TABLE public.incident_events TO authenticated;

CREATE POLICY "Read timeline of visible incidents" ON public.incident_events
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.incidents i
        WHERE i.id = incident_events.incident_id
          AND (i.created_by = (SELECT auth.uid()) OR (SELECT public.is_incident_manager()))));

REVOKE ALL ON FUNCTION
    public.prevent_history_change(),
    public.redact_sensitive(jsonb),
    public.log_audit_event(text, text, uuid, jsonb),
    public.write_incident_event(uuid, text, text, jsonb, text),
    public.add_incident_event(uuid, text, text, jsonb, text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.add_incident_event(uuid, text, text, jsonb, text) TO authenticated;
