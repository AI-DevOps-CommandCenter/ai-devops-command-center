-- Rollback for 20261107000600_notifications.sql
-- Safety: refuses to run when a row uses a channel that the old CHECK does not
-- allow (slack, discord), because restoring the old CHECK would fail or the
-- rows would have to be changed.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.notifications WHERE channel IN ('slack', 'discord'))
       OR EXISTS (SELECT 1 FROM public.notification_deliveries WHERE channel IN ('slack', 'discord')) THEN
        RAISE EXCEPTION 'Rollback refused: notifications use slack/discord channels. Export them first and get approval.';
    END IF;
END
$$;

REVOKE SELECT ON TABLE public.notifications, public.device_tokens FROM authenticated;
DROP POLICY IF EXISTS "Users read own notifications" ON public.notifications;

DROP FUNCTION IF EXISTS public.record_notification_delivery(uuid, text, text, text);
DROP FUNCTION IF EXISTS public.claim_notification_deliveries(integer);
DROP FUNCTION IF EXISTS public.create_notification(uuid, uuid, text, text, text[]);
DROP FUNCTION IF EXISTS public.mark_notification_read(uuid);
DROP FUNCTION IF EXISTS public.unregister_device_token(text);
DROP FUNCTION IF EXISTS public.register_device_token(text, text);
DROP FUNCTION IF EXISTS public.write_notification(uuid, uuid, text, text, text[]);

ALTER TABLE public.notification_deliveries DROP CONSTRAINT notification_deliveries_channel_check;
ALTER TABLE public.notification_deliveries ADD CONSTRAINT notification_deliveries_channel_check
    CHECK (channel = ANY (ARRAY['in_app', 'push', 'email', 'telegram']));

ALTER TABLE public.notifications DROP CONSTRAINT notifications_channel_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_channel_check
    CHECK ((channel = ANY (ARRAY['in_app'::text, 'push'::text, 'email'::text, 'telegram'::text])));
