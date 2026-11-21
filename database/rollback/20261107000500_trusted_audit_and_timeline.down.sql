-- Rollback for 20261107000500_trusted_audit_and_timeline.sql
-- Safety: refuses to run when an audit or timeline row names an actor whose
-- profile no longer exists. Restoring the FK would require rewriting that
-- history, which the append-only decision (A7) forbids.
-- Note: removing the append-only triggers makes history editable again.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.audit_logs a
               WHERE a.actor_id IS NOT NULL
                 AND NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = a.actor_id))
       OR EXISTS (SELECT 1 FROM public.incident_events e
                  WHERE e.actor_id IS NOT NULL
                    AND NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = e.actor_id)) THEN
        RAISE EXCEPTION 'Rollback refused: history references deleted profiles; the actor FK cannot be restored without rewriting history.';
    END IF;
END
$$;

-- Access back to the previous state
DROP POLICY IF EXISTS "Read timeline of visible incidents" ON public.incident_events;
REVOKE SELECT ON TABLE public.incident_events FROM authenticated;
GRANT INSERT ON TABLE public.audit_logs TO authenticated;

DROP FUNCTION IF EXISTS public.add_incident_event(uuid, text, text, jsonb, text);
DROP FUNCTION IF EXISTS public.write_incident_event(uuid, text, text, jsonb, text);
DROP FUNCTION IF EXISTS public.log_audit_event(text, text, uuid, jsonb);
DROP FUNCTION IF EXISTS public.redact_sensitive(jsonb);

DROP TRIGGER IF EXISTS incident_events_no_truncate ON public.incident_events;
DROP TRIGGER IF EXISTS incident_events_append_only ON public.incident_events;
DROP TRIGGER IF EXISTS audit_logs_no_truncate ON public.audit_logs;
DROP TRIGGER IF EXISTS audit_logs_append_only ON public.audit_logs;
DROP FUNCTION IF EXISTS public.prevent_history_change();

COMMENT ON COLUMN public.incident_events.actor_id IS NULL;
COMMENT ON COLUMN public.audit_logs.actor_id IS NULL;

ALTER TABLE public.incident_events ADD CONSTRAINT incident_events_actor_id_fkey
    FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.audit_logs ADD CONSTRAINT audit_logs_actor_id_fkey
    FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE SET NULL;
