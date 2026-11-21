-- =============================================================================
-- GROUP 33 | CLEANUP: OLD MOCK PUSH TOKENS | REVIEW ONLY
-- Prepared: 2026-11-18, for the 20 Nov cleanup.
-- Tested on a temporary local DB and run on staging on 21 Nov 2026 (4 mock tokens deleted).
--
-- DO NOT RUN without Vishwa's explicit approval.
--
-- Removes the fake device tokens the old mobile code saved before real FCM
-- tokens existed (device_token starting with 'web-fcm-token-').
-- Real FCM tokens never start with that prefix, so they are not touched.
--
-- Side effect: notification_deliveries.device_token_id is ON DELETE SET NULL,
-- so delivery history stays; those rows only lose the link to the fake token.
--
-- Run part 1 first and check the rows. Run part 2 only if they are all mock
-- tokens. Part 2 aborts if the rows changed in between or look like real tokens.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PART 1: PREVIEW (read only)
-- -----------------------------------------------------------------------------
SELECT dt.id,
       dt.user_id,
       p.email,
       dt.platform,
       left(dt.device_token, 30) AS token_start,
       length(dt.device_token)   AS token_length,
       dt.created_at,
       (SELECT count(*) FROM public.notification_deliveries nd
         WHERE nd.device_token_id = dt.id) AS linked_deliveries
FROM public.device_tokens dt
LEFT JOIN public.profiles p ON p.id = dt.user_id
WHERE dt.device_token LIKE 'web-fcm-token-%'
ORDER BY dt.created_at;

SELECT count(*) AS mock_tokens_to_delete
FROM public.device_tokens
WHERE device_token LIKE 'web-fcm-token-%';

-- -----------------------------------------------------------------------------
-- PART 2: DELETE (guarded, one transaction)
-- Set v_expected to the count from part 1 before running.
-- -----------------------------------------------------------------------------
BEGIN;

DO $cleanup$
DECLARE
  v_expected integer := NULL;  -- <- put the part 1 count here
  v_found    integer;
  v_deleted  integer;
BEGIN
  IF v_expected IS NULL THEN
    RAISE EXCEPTION 'Set v_expected to the part 1 count first; nothing deleted.';
  END IF;

  SELECT count(*) INTO v_found
  FROM public.device_tokens
  WHERE device_token LIKE 'web-fcm-token-%';

  IF v_found <> v_expected THEN
    RAISE EXCEPTION 'Found % mock tokens, expected %; nothing deleted.', v_found, v_expected;
  END IF;

  -- Real FCM tokens contain ':' and are long; refuse if a match looks real.
  IF EXISTS (
    SELECT 1 FROM public.device_tokens
    WHERE device_token LIKE 'web-fcm-token-%'
      AND (position(':' IN device_token) > 0 OR length(device_token) > 100)
  ) THEN
    RAISE EXCEPTION 'A matching token looks like a real FCM token; nothing deleted.';
  END IF;

  DELETE FROM public.device_tokens
  WHERE device_token LIKE 'web-fcm-token-%';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  IF v_deleted <> v_expected THEN
    RAISE EXCEPTION 'Deleted % rows, expected %; rolled back.', v_deleted, v_expected;
  END IF;

  RAISE NOTICE 'Deleted % mock device tokens.', v_deleted;
END
$cleanup$;

COMMIT;

-- Check afterwards (expect 0):
-- SELECT count(*) FROM public.device_tokens WHERE device_token LIKE 'web-fcm-token-%';
