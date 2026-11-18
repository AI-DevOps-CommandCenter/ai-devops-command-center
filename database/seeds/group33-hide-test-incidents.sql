-- =============================================================================
-- GROUP 33 | HIDE TEST INCIDENTS before the 20 Nov rehearsal | REVIEW ONLY
-- Prepared: 2026-11-18. Run only after Vishwa approves the id list below.
--
-- Why not DELETE: approvals_immutable_decision (migration 20261107000700)
-- blocks deleting a decided approval, and the incidents below have them.
-- Instead they are marked environment = 'test'; the backend leaves
-- environment = 'test' out of GET /api/incidents (incident list, History)
-- and the dashboard counts (branch feature/demo-seed-v3).
-- Real alert incidents "HighErrorRate on sample-app" (8bf69678, 256aee75,
-- 5faa19d5) are kept.
-- =============================================================================

-- 1. Preview (read-only): must return exactly these 6 rows.
SELECT id, title, status, environment, created_at
FROM public.incidents
WHERE id IN (
  '0fd5b5bd-754e-4d88-a144-50e51a1228e0', -- Outbox live test (sample-app)
  '6b0612e9-81d8-4c76-b36b-2c4b26263228', -- Push live test (sample-app)
  'efc31843-6ee9-486a-b6e9-e673a479cff3', -- Push live test (sample-app)
  'bc074803-2f4f-460d-a23d-7e417b349529', -- Push live test (sample-app)
  'd3310000-0000-4000-8000-000000000001', -- old demo seed v2 (replaced by v3)
  '38b1ccbc-fea7-4d92-af5f-09f366854d68'  -- TEST_AUDIT_RUNTIME_INCIDENT (8 Nov)
)
ORDER BY created_at;

-- 2. The change (one transaction; aborts unless exactly 6 rows change).
BEGIN;
DO $hide$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.incidents
     SET environment = 'test'
   WHERE id IN (
     '0fd5b5bd-754e-4d88-a144-50e51a1228e0',
     '6b0612e9-81d8-4c76-b36b-2c4b26263228',
     'efc31843-6ee9-486a-b6e9-e673a479cff3',
     'bc074803-2f4f-460d-a23d-7e417b349529',
     'd3310000-0000-4000-8000-000000000001',
     '38b1ccbc-fea7-4d92-af5f-09f366854d68'
   );
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count <> 6 THEN
    RAISE EXCEPTION 'Expected 6 test incidents, matched %. Nothing changed.', v_count;
  END IF;
END;
$hide$;
COMMIT;
