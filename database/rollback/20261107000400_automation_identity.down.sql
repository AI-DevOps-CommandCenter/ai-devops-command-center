-- Rollback for 20261107000400_automation_identity.sql
-- Safety: refuses to run while a profile still has the automation role
-- (restoring the old CHECK would fail, and the role must be removed by the
-- owner on purpose first). The nonce table only holds short-lived replay
-- protection data (max. 15 minutes) and is dropped.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.profiles WHERE role = 'automation') THEN
        RAISE EXCEPTION 'Rollback refused: a profile has the automation role. Remove the automation identity first (owner, with approval).';
    END IF;
END
$$;

DROP FUNCTION IF EXISTS public.consume_automation_nonce(text, timestamptz);
DROP TABLE IF EXISTS public.automation_request_nonces;
DROP FUNCTION IF EXISTS public.require_app_role(text[]);
DROP FUNCTION IF EXISTS public.current_app_role();

DROP TRIGGER IF EXISTS guard_automation_role ON public.profiles;
DROP FUNCTION IF EXISTS public.guard_automation_role();

ALTER TABLE public.profiles DROP CONSTRAINT profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
    CHECK ((role = ANY (ARRAY['user'::text, 'admin'::text, 'operator'::text])));
