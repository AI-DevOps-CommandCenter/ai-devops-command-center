-- Rollback for 20261117000100_alert_intake_and_postmortems.sql
-- Drops the BD-1/BD-4 functions, restores the 000700 record_ai_analysis and
-- removes the two new columns. Refuses to run while those columns hold data
-- (incidents created from alerts, saved postmortem reports): nothing is lost
-- silently.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.incidents WHERE alert_fingerprint IS NOT NULL)
       OR EXISTS (SELECT 1 FROM public.postmortems WHERE report IS NOT NULL) THEN
        RAISE EXCEPTION 'Rollback refused: incidents.alert_fingerprint or postmortems.report contains data.';
    END IF;
END;
$$;

DROP FUNCTION IF EXISTS public.create_incident_from_alert(text, text, text, text, text, text, timestamptz);
DROP FUNCTION IF EXISTS public.get_incident_context(uuid);
DROP FUNCTION IF EXISTS public.save_postmortem(uuid, text, text, text, jsonb, text, jsonb, jsonb);

-- Restore the 000700 version (does not update investigations).
CREATE OR REPLACE FUNCTION public.record_ai_analysis(
    p_incident_id uuid,
    p_investigation_id uuid,
    p_model_name text,
    p_summary text,
    p_root_cause text,
    p_severity text,
    p_confidence numeric,
    p_evidence jsonb,
    p_recommended_action text
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_id uuid;
BEGIN
    PERFORM public.require_app_role(ARRAY['automation']);

    IF NOT EXISTS (SELECT 1 FROM public.incidents WHERE id = p_incident_id) THEN
        RAISE EXCEPTION 'Incident not found.' USING ERRCODE = 'DC404';
    END IF;
    IF p_investigation_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.investigations WHERE id = p_investigation_id AND incident_id = p_incident_id) THEN
        RAISE EXCEPTION 'The investigation does not belong to this incident.' USING ERRCODE = 'DC422';
    END IF;
    IF p_evidence IS NOT NULL AND jsonb_typeof(p_evidence) <> 'array' THEN
        RAISE EXCEPTION 'Evidence must be a JSON array.' USING ERRCODE = 'DC422';
    END IF;
    IF length(coalesce(p_summary, '') || coalesce(p_root_cause, '') || coalesce(p_evidence::text, '')) > 32000 THEN
        RAISE EXCEPTION 'AI analysis too large.' USING ERRCODE = 'DC422';
    END IF;

    -- severity, confidence and recommended_action are validated by the table's CHECKs.
    INSERT INTO public.ai_analyses
        (incident_id, investigation_id, model_name, summary, root_cause, severity, confidence,
         evidence, recommended_action)
    VALUES
        (p_incident_id, p_investigation_id, left(p_model_name, 100), p_summary, p_root_cause, p_severity,
         p_confidence, coalesce(p_evidence, '[]'::jsonb), p_recommended_action)
    RETURNING id INTO v_id;

    PERFORM public.log_audit_event('AI_ANALYSIS_RECORDED', 'ai_analysis', v_id,
        jsonb_build_object('incident_id', p_incident_id, 'investigation_id', p_investigation_id,
                           'model_name', p_model_name, 'recommended_action', p_recommended_action));
    PERFORM public.write_incident_event(p_incident_id, 'investigation', 'AI analysis recorded',
        jsonb_build_object('ai_analysis_id', v_id, 'recommended_action', p_recommended_action));

    RETURN v_id;
END;
$$;

DROP INDEX IF EXISTS public.incidents_active_alert_fingerprint_key;
ALTER TABLE public.postmortems DROP COLUMN IF EXISTS report;
ALTER TABLE public.incidents DROP COLUMN IF EXISTS alert_fingerprint;
