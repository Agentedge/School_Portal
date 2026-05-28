-- Migration M023: Backfill 'Not Submitted' rows for full-grid convention
-- Date: 2026-05-16
-- Decision: D-2026-05-16-01 — biz_001.homework_submissions uses Style A
--           (every (student, homework) cell ALWAYS has a row; 'Not Submitted'
--           is the explicit absence-marker, not row-absence).
-- Purpose: One-shot backfill of the 20 missing (student, homework) cells in
--          biz_001.homework_submissions to bring the seed to full grid 8×6=48.
-- Scope:   biz_001 schema only. Class 9 Section A only.
-- Expected: 20 rows inserted (48 grid cells - 28 existing rows = 20 missing).
-- 
-- STATUS: Already applied to biz_001 on 2026-05-16 (this session).
-- Re-runnable: NOT EXISTS guard makes the second run insert 0 rows.
--
-- Follow-up: M024 added an AFTER INSERT trigger on biz_001.homework that
-- enforces this invariant going forward — so this M023 backfill is the
-- LAST manual application of the Style A convention. All future homework
-- INSERTs cascade their Not Submitted rows automatically.

BEGIN;

INSERT INTO biz_001.homework_submissions (
  business_id,
  homework_id,
  student_id,
  status,
  submitted_at,
  score
)
SELECT 
  'biz_001',
  h.homework_id,
  sp.entity_id,
  'Not Submitted',
  NULL,                -- explicit NULL overrides the now() default
  NULL                 -- no score for not-submitted
FROM biz_001.homework h
CROSS JOIN biz_001.student_profiles sp
JOIN biz_001.entities e ON e.id = sp.entity_id
WHERE h.is_active            = true
  AND h.class                = '9' 
  AND h.section              = 'A'
  AND sp.class               = '9'
  AND sp.section             = 'A'
  AND sp.enrollment_status   = 'enrolled'
  AND e.status               = 'active'
  AND NOT EXISTS (
    SELECT 1 
    FROM biz_001.homework_submissions s
    WHERE s.homework_id = h.homework_id 
      AND s.student_id  = sp.entity_id
  );

COMMIT;

-- ────────────────────────────────────────────────────────────────────
-- POST-DEPLOY VERIFICATION (run separately after the migration commits)
-- ────────────────────────────────────────────────────────────────────
-- Expected result: 48 total submission rows across 4 status values.
--
--   SELECT status, COUNT(*) AS row_count
--   FROM biz_001.homework_submissions
--   GROUP BY status
--   ORDER BY status;
--
-- Expected:
--   Graded         18
--   Late            2
--   Not Submitted  24  (4 existing + 20 new)
--   Submitted       4
--   Total          48
