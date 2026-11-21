-- Rollback for 20261118000100_notification_preferences.sql
-- Restores the 20261107000600 write_notification (no preferences), drops the
-- two preference functions and the table. Refuses to run while users have
-- saved preferences: nothing is lost silently.

DO $$
BEGIN
    IF to_regclass('public.notification_preferences') IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.notification_preferences) THEN
        RAISE EXCEPTION 'Rollback refused: public.notification_preferences contains saved preferences.';
    END IF;
END;
$$;

DROP FUNCTION IF EXISTS public.get_notification_preferences();
DROP FUNCTION IF EXISTS public.set_notification_preferences(boolean, boolean);
DROP TABLE IF EXISTS public.notification_preferences;

-- The 20261107000600 version, unchanged.
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

REVOKE ALL ON FUNCTION public.write_notification(uuid, uuid, text, text, text[])
FROM PUBLIC, anon, authenticated;
