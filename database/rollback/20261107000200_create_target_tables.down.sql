-- Rollback for 20261107000200_create_target_tables.sql
-- Run 20261107000300 rollback first (link columns reference automation_runs).
-- Safety: refuses to drop a table that contains rows.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.automation_runs)
       OR EXISTS (SELECT 1 FROM public.incident_events)
       OR EXISTS (SELECT 1 FROM public.notification_deliveries) THEN
        RAISE EXCEPTION 'Rollback refused: new tables contain data. Export it first and get approval.';
    END IF;
END
$$;

DROP TABLE IF EXISTS public.notification_deliveries;
DROP TABLE IF EXISTS public.incident_events;
DROP TABLE IF EXISTS public.automation_runs;
