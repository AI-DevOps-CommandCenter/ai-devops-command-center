-- Rollback for 20261118000400_local_releases.sql
-- Drops the two functions, the index, the checks and the two new columns.
-- Refuses to run while recorded releases exist (service_name or version set):
-- nothing is lost silently.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.deployments WHERE service_name IS NOT NULL OR version IS NOT NULL) THEN
        RAISE EXCEPTION 'Rollback refused: deployments.service_name or deployments.version contains data.';
    END IF;
END;
$$;

DROP FUNCTION IF EXISTS public.list_recent_deployments(text, timestamptz, timestamptz);
DROP FUNCTION IF EXISTS public.record_deployment(text, text, text, text);
DROP INDEX IF EXISTS public.idx_deployments_service_name_completed_at;
ALTER TABLE public.deployments DROP CONSTRAINT IF EXISTS deployments_version_check;
ALTER TABLE public.deployments DROP CONSTRAINT IF EXISTS deployments_service_name_check;
ALTER TABLE public.deployments DROP COLUMN IF EXISTS version;
ALTER TABLE public.deployments DROP COLUMN IF EXISTS service_name;
