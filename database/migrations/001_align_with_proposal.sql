-- 001: Align the database with the project proposal
-- Does not recreate existing tables.

BEGIN;

-- 1. Rename the three existing starter playbooks.
UPDATE public.playbooks
SET name = 'restart', action_type = 'restart'
WHERE name = 'restart_service';

UPDATE public.playbooks
SET name = 'rollback', action_type = 'rollback'
WHERE name = 'rollback_deployment';

UPDATE public.playbooks
SET name = 'scale', action_type = 'scale'
WHERE name = 'scale_service';

-- 2. Add the circuit breaker playbook if it does not exist.
INSERT INTO public.playbooks
    (name, description, action_type, configuration, enabled, requires_approval)
VALUES
    (
        'circuit_breaker',
        'Temporarily stop requests to a failing dependency.',
        'circuit_breaker',
        '{"approval_required": true}'::jsonb,
        false,
        true
    )
ON CONFLICT (name) DO NOTHING;

-- 3. Restrict playbook action types to the four approved values.
ALTER TABLE public.playbooks
DROP CONSTRAINT IF EXISTS playbooks_action_type_allowed;

ALTER TABLE public.playbooks
ADD CONSTRAINT playbooks_action_type_allowed
CHECK (
    action_type IN ('restart', 'rollback', 'scale', 'circuit_breaker')
);

-- 4. Add the AI analysis fields.
ALTER TABLE public.ai_analyses
ADD COLUMN IF NOT EXISTS severity text;

ALTER TABLE public.ai_analyses
ADD COLUMN IF NOT EXISTS recommended_action text;

-- 5. Restrict severity values.
ALTER TABLE public.ai_analyses
DROP CONSTRAINT IF EXISTS ai_analyses_severity_allowed;

ALTER TABLE public.ai_analyses
ADD CONSTRAINT ai_analyses_severity_allowed
CHECK (
    severity IS NULL
    OR severity IN ('low', 'medium', 'high', 'critical')
);

-- 6. Restrict recommended actions.
ALTER TABLE public.ai_analyses
DROP CONSTRAINT IF EXISTS ai_analyses_action_allowed;

ALTER TABLE public.ai_analyses
ADD CONSTRAINT ai_analyses_action_allowed
CHECK (
    recommended_action IS NULL
    OR recommended_action IN ('restart', 'rollback', 'scale', 'circuit_breaker')
);

-- 7. Set confidence to the 0–1 range.
ALTER TABLE public.ai_analyses
DROP CONSTRAINT IF EXISTS ai_analyses_confidence_check;

ALTER TABLE public.ai_analyses
DROP CONSTRAINT IF EXISTS ai_analyses_confidence_range;

ALTER TABLE public.ai_analyses
ADD CONSTRAINT ai_analyses_confidence_range
CHECK (
    confidence IS NULL
    OR (confidence >= 0 AND confidence <= 1)
);

-- 8. Make the default evidence value an empty JSON array.
ALTER TABLE public.ai_analyses
ALTER COLUMN evidence SET DEFAULT '[]'::jsonb;

COMMIT;