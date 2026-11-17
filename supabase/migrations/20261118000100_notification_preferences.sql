-- =============================================================================
-- Migration: per-user notification preferences (mobile screen S27)
--
--   notification_preferences  one row per user, created on the first save.
--                             No row = the defaults: push on, email off.
--   get_notification_preferences()          the caller's settings (or defaults)
--   set_notification_preferences(push, email)  the caller saves own settings
--   write_notification (replaced)  applies the recipient's settings:
--       push_enabled = false  -> no push delivery
--       email_enabled = true  -> an email delivery is added
--     The in-app inbox is always written. Team channels (slack, discord) and
--     notifications without a recipient are not affected.
--
-- Users read their own row (RLS); all writes go through the functions, like
-- the other notification tables (A6). The user id always comes from the JWT.
-- Rollback: database/rollback/20261118000100_notification_preferences.down.sql
-- =============================================================================

-- 1. Table ---------------------------------------------------------------------
CREATE TABLE public.notification_preferences (
    user_id uuid PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
    push_enabled boolean NOT NULL DEFAULT true,
    email_enabled boolean NOT NULL DEFAULT false,
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.notification_preferences IS
    'Per-user notification channels (S27). No row = defaults (push on, email off). Written only by set_notification_preferences().';

-- 2. Functions for signed-in users --------------------------------------------------
CREATE FUNCTION public.get_notification_preferences()
RETURNS TABLE (push_enabled boolean, email_enabled boolean, updated_at timestamptz)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['user', 'operator', 'admin']);
BEGIN
    RETURN QUERY
    SELECT coalesce(p.push_enabled, true), coalesce(p.email_enabled, false), p.updated_at
    FROM (SELECT 1) AS one
    LEFT JOIN public.notification_preferences p ON p.user_id = v_uid;
END;
$$;

CREATE FUNCTION public.set_notification_preferences(p_push_enabled boolean, p_email_enabled boolean)
RETURNS TABLE (push_enabled boolean, email_enabled boolean, updated_at timestamptz)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['user', 'operator', 'admin']);
BEGIN
    IF p_push_enabled IS NULL OR p_email_enabled IS NULL THEN
        RAISE EXCEPTION 'push_enabled and email_enabled are required.' USING ERRCODE = 'DC422';
    END IF;

    RETURN QUERY
    INSERT INTO public.notification_preferences AS np (user_id, push_enabled, email_enabled, updated_at)
    VALUES (v_uid, p_push_enabled, p_email_enabled, now())
    ON CONFLICT (user_id) DO UPDATE
        SET push_enabled = EXCLUDED.push_enabled,
            email_enabled = EXCLUDED.email_enabled,
            updated_at = now()
    RETURNING np.push_enabled, np.email_enabled, np.updated_at;
END;
$$;

-- 3. write_notification applies the recipient's settings ----------------------------
-- Same signature, checks and inbox row as 20261107000600; only the channel list
-- for a user recipient changes.
CREATE OR REPLACE FUNCTION public.write_notification(
    p_user_id uuid,
    p_incident_id uuid,
    p_title text,
    p_message text,
    p_channels text[]
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_id uuid;
    v_channel text;
    v_channels text[] := ARRAY(SELECT DISTINCT unnest(coalesce(p_channels, ARRAY['in_app'])));
    v_push boolean;
    v_email boolean;
BEGIN
    IF p_title IS NULL OR btrim(p_title) = '' OR length(p_title) > 200
       OR p_message IS NULL OR btrim(p_message) = '' OR length(p_message) > 2000 THEN
        RAISE EXCEPTION 'Notification title (max 200) and message (max 2000) are required.'
            USING ERRCODE = 'DC422';
    END IF;

    IF cardinality(v_channels) = 0
       OR NOT v_channels <@ ARRAY['in_app', 'push', 'email', 'slack', 'discord'] THEN
        RAISE EXCEPTION 'Unknown notification channel.' USING ERRCODE = 'DC422';
    END IF;

    IF p_user_id IS NULL AND v_channels && ARRAY['in_app', 'push', 'email'] THEN
        RAISE EXCEPTION 'in_app, push and email need a recipient user.' USING ERRCODE = 'DC422';
    END IF;

    -- S27: the recipient's settings (no row = push on, email off).
    IF p_user_id IS NOT NULL THEN
        SELECT np.push_enabled, np.email_enabled INTO v_push, v_email
        FROM public.notification_preferences np WHERE np.user_id = p_user_id;
        IF coalesce(v_push, true) = false THEN
            v_channels := array_remove(v_channels, 'push');
        END IF;
        IF coalesce(v_email, false) AND NOT 'email' = ANY (v_channels) THEN
            v_channels := v_channels || 'email'::text;
        END IF;
    END IF;

    INSERT INTO public.notifications (user_id, incident_id, title, message, channel, status, sent_at)
    VALUES (
        p_user_id, p_incident_id, p_title, p_message,
        CASE WHEN p_user_id IS NOT NULL THEN 'in_app' ELSE v_channels[1] END,
        CASE WHEN p_user_id IS NOT NULL AND 'in_app' = ANY (v_channels) THEN 'sent' ELSE 'pending' END,
        CASE WHEN p_user_id IS NOT NULL AND 'in_app' = ANY (v_channels) THEN now() END)
    RETURNING id INTO v_id;

    FOREACH v_channel IN ARRAY v_channels LOOP
        IF v_channel <> 'in_app' THEN
            INSERT INTO public.notification_deliveries (notification_id, channel, status)
            VALUES (v_id, v_channel, 'pending');
        END IF;
    END LOOP;

    RETURN v_id;
END;
$$;

-- 4. Access ---------------------------------------------------------------------------
GRANT SELECT ON TABLE public.notification_preferences TO authenticated;

CREATE POLICY "Users read own notification preferences" ON public.notification_preferences
    FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid()));

REVOKE ALL ON FUNCTION
    public.get_notification_preferences(),
    public.set_notification_preferences(boolean, boolean),
    public.write_notification(uuid, uuid, text, text, text[])
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
    public.get_notification_preferences(),
    public.set_notification_preferences(boolean, boolean)
TO authenticated;
