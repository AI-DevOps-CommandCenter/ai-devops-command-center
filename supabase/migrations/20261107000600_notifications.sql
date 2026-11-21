-- =============================================================================
-- Migration: notifications data access for the backend notification module
-- Decision:  A6 (approved 2026-11-07): notifications are managed by the backend
--            notification module; channels in_app, push, email, slack,
--            discord (also answers R4); provider credentials stay on the
--            backend. D-001: no service_role, so the module works through the
--            functions below with the automation identity.
-- Rollback:  database/rollback/20261107000600_notifications.down.sql
--
-- Model:
--   notifications            one inbox row per user (user_id NULL = team
--                            broadcast, e.g. Slack/Discord, not shown in any inbox)
--   notification_deliveries  one row per channel to send; the backend claims
--                            pending rows, sends them and records the result
--
-- Who may create notifications for other people: only the workflow functions
-- (internally) and the automation identity. Humans cannot notify others
-- directly (safe default for the open A6-Q3).
-- =============================================================================

-- 1. Channels (A6 / R4) -----------------------------------------------------------
-- Fails, and so aborts the migration, if a row uses a channel outside the new
-- set (production had 0 notifications when this was written).
ALTER TABLE public.notifications DROP CONSTRAINT notifications_channel_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_channel_check
    CHECK (channel = ANY (ARRAY['in_app'::text, 'push'::text, 'email'::text, 'slack'::text, 'discord'::text]));

ALTER TABLE public.notification_deliveries DROP CONSTRAINT notification_deliveries_channel_check;
ALTER TABLE public.notification_deliveries ADD CONSTRAINT notification_deliveries_channel_check
    CHECK (channel = ANY (ARRAY['in_app'::text, 'push'::text, 'email'::text, 'slack'::text, 'discord'::text]));

-- 2. Internal writer --------------------------------------------------------------
-- Creates the inbox row (when there is a user) and one pending delivery per
-- external channel. INTERNAL: no client EXECUTE.
CREATE FUNCTION public.write_notification(
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

-- 3. Functions for signed-in users --------------------------------------------------
-- The user id always comes from the JWT, never from the request body.
CREATE FUNCTION public.register_device_token(p_device_token text, p_platform text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['user', 'operator', 'admin']);
    v_id uuid;
BEGIN
    IF p_device_token IS NULL OR length(p_device_token) NOT BETWEEN 10 AND 4096 THEN
        RAISE EXCEPTION 'Invalid device token.' USING ERRCODE = 'DC422';
    END IF;
    IF p_platform IS NULL OR p_platform NOT IN ('android', 'ios', 'web') THEN
        RAISE EXCEPTION 'Platform must be android, ios or web.' USING ERRCODE = 'DC422';
    END IF;

    -- A token identifies a device; if another account used this device before,
    -- the token moves to the account that is signed in now.
    INSERT INTO public.device_tokens (user_id, device_token, platform)
    VALUES (v_uid, p_device_token, p_platform)
    ON CONFLICT (device_token) DO UPDATE
        SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

CREATE FUNCTION public.unregister_device_token(p_device_token text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['user', 'operator', 'admin']);
BEGIN
    DELETE FROM public.device_tokens WHERE device_token = p_device_token AND user_id = v_uid;
    RETURN FOUND;
END;
$$;

CREATE FUNCTION public.mark_notification_read(p_notification_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
DECLARE
    v_uid uuid := public.require_app_role(ARRAY['user', 'operator', 'admin']);
BEGIN
    UPDATE public.notifications
    SET status = 'read', read_at = coalesce(read_at, now())
    WHERE id = p_notification_id AND user_id = v_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Notification not found.' USING ERRCODE = 'DC404';
    END IF;
    RETURN true;
END;
$$;

-- 4. Functions for the backend notification module (automation identity) ------------
CREATE FUNCTION public.create_notification(
    p_user_id uuid,
    p_incident_id uuid,
    p_title text,
    p_message text,
    p_channels text[] DEFAULT ARRAY['in_app', 'push']
) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
    PERFORM public.require_app_role(ARRAY['automation']);

    IF p_user_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.profiles WHERE id = p_user_id AND role <> 'automation') THEN
        RAISE EXCEPTION 'Recipient not found.' USING ERRCODE = 'DC404';
    END IF;

    RETURN public.write_notification(p_user_id, p_incident_id, p_title, p_message, p_channels);
END;
$$;

-- Claims up to p_limit pending deliveries (not attempted in the last 2 minutes)
-- and returns what the backend needs to send them.
CREATE FUNCTION public.claim_notification_deliveries(p_limit integer DEFAULT 50)
RETURNS TABLE (
    delivery_id uuid,
    channel text,
    attempt_count integer,
    notification_id uuid,
    user_id uuid,
    incident_id uuid,
    title text,
    message text,
    recipient_email text,
    device_tokens text[]
)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
#variable_conflict use_column
BEGIN
    PERFORM public.require_app_role(ARRAY['automation']);

    IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN
        RAISE EXCEPTION 'Limit must be between 1 and 500.' USING ERRCODE = 'DC422';
    END IF;

    RETURN QUERY
    WITH claimed AS (
        UPDATE public.notification_deliveries d
        SET attempt_count = d.attempt_count + 1, attempted_at = now()
        WHERE d.id IN (
            SELECT id FROM public.notification_deliveries
            WHERE status = 'pending'
              AND (attempted_at IS NULL OR attempted_at < now() - interval '2 minutes')
            ORDER BY created_at
            LIMIT p_limit
            FOR UPDATE SKIP LOCKED)
        RETURNING d.*
    )
    SELECT c.id, c.channel, c.attempt_count, n.id, n.user_id, n.incident_id, n.title, n.message,
           CASE WHEN c.channel = 'email' THEN p.email END,
           CASE WHEN c.channel = 'push' THEN
               ARRAY(SELECT t.device_token FROM public.device_tokens t WHERE t.user_id = n.user_id)
           END
    FROM claimed c
    JOIN public.notifications n ON n.id = c.notification_id
    LEFT JOIN public.profiles p ON p.id = n.user_id;
END;
$$;

CREATE FUNCTION public.record_notification_delivery(
    p_delivery_id uuid,
    p_status text,
    p_provider_message_id text DEFAULT NULL,
    p_error_message text DEFAULT NULL
) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO ''
    AS $$
BEGIN
    PERFORM public.require_app_role(ARRAY['automation']);

    IF p_status IS NULL OR p_status NOT IN ('sent', 'delivered', 'failed') THEN
        RAISE EXCEPTION 'Status must be sent, delivered or failed.' USING ERRCODE = 'DC422';
    END IF;

    UPDATE public.notification_deliveries
    SET status = p_status,
        provider_message_id = left(p_provider_message_id, 200),
        error_message = left(p_error_message, 500),
        delivered_at = CASE WHEN p_status IN ('sent', 'delivered') THEN now() END
    WHERE id = p_delivery_id AND status IN ('pending', 'sent');

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Delivery not found or already final.' USING ERRCODE = 'DC409';
    END IF;
END;
$$;

-- 5. Access ---------------------------------------------------------------------------
-- Users read their own inbox and devices (RLS); all writes go through functions.
GRANT SELECT ON TABLE public.notifications TO authenticated;
GRANT SELECT ON TABLE public.device_tokens TO authenticated;

CREATE POLICY "Users read own notifications" ON public.notifications
    FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid()));
-- device_tokens already has device_tokens_select_own (baseline).

REVOKE ALL ON FUNCTION
    public.write_notification(uuid, uuid, text, text, text[]),
    public.register_device_token(text, text),
    public.unregister_device_token(text),
    public.mark_notification_read(uuid),
    public.create_notification(uuid, uuid, text, text, text[]),
    public.claim_notification_deliveries(integer),
    public.record_notification_delivery(uuid, text, text, text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
    public.register_device_token(text, text),
    public.unregister_device_token(text),
    public.mark_notification_read(uuid),
    public.create_notification(uuid, uuid, text, text, text[]),
    public.claim_notification_deliveries(integer),
    public.record_notification_delivery(uuid, text, text, text)
TO authenticated;
