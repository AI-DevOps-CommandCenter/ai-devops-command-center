-- Rollback for 20261107000800_audit_coverage_and_redaction.sql
-- Removes triggers and functions only; no table or row is changed. Audit
-- entries and timeline events already written stay (they are append-only).
-- Note: after this rollback, direct-write actions are no longer audited and
-- run payloads are no longer redacted.

DROP TRIGGER IF EXISTS incidents_status_event ON public.incidents;
DROP TRIGGER IF EXISTS audit_profile_role ON public.profiles;
DROP TRIGGER IF EXISTS audit_integrations ON public.integrations;
DROP TRIGGER IF EXISTS audit_playbooks ON public.playbooks;
DROP TRIGGER IF EXISTS audit_postmortems ON public.postmortems;
DROP TRIGGER IF EXISTS audit_incidents ON public.incidents;
DROP TRIGGER IF EXISTS automation_runs_redact_payloads ON public.automation_runs;
DROP TRIGGER IF EXISTS playbook_runs_redact_payloads ON public.playbook_runs;

DROP FUNCTION IF EXISTS public.incident_status_event();
DROP FUNCTION IF EXISTS public.audit_row_change();
DROP FUNCTION IF EXISTS public.redact_run_payloads();

-- Restore the 000500 version (top-level keys only), then drop the helper.
CREATE OR REPLACE FUNCTION public.redact_sensitive(p_details jsonb) RETURNS jsonb
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

DROP FUNCTION IF EXISTS public.redact_json(jsonb);
