-- Migration M024: Auto-create 'Not Submitted' rows on homework INSERT
-- Date: 2026-05-16
-- Stage: 6a (HomeworkTab build prerequisite)
-- Decision: Enforces Style A (full-grid) convention at the database level.
--           Replaces what M023 did as one-shot backfill; this trigger makes
--           the invariant self-maintaining for all future homework rows.
-- Scope:    biz_001.homework AFTER INSERT → cascade to biz_001.homework_submissions
-- Idempotent: trigger is DROPped first; function is CREATE OR REPLACE.

BEGIN;

-- ────────────────────────────────────────────────────────────────────
-- 1. The trigger function
-- ────────────────────────────────────────────────────────────────────
-- For each just-inserted homework row, create one 'Not Submitted' row
-- per enrolled+active student in the matching class+section.
--
-- SECURITY DEFINER: the function runs with table-owner privileges so it
--   can INSERT into homework_submissions regardless of the teacher's RLS.
--   The function body is tightly scoped (only inserts rows tied to NEW.*)
--   so it cannot be abused even by a malicious INSERT to homework.
-- search_path is pinned to prevent any schema-injection trick.

CREATE OR REPLACE FUNCTION biz_001.create_homework_submission_grid()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = biz_001, ae_platform, public
AS $$
BEGIN
  INSERT INTO biz_001.homework_submissions (
    business_id,
    homework_id,
    student_id,
    status,
    submitted_at,
    score
  )
  SELECT
    NEW.business_id,
    NEW.homework_id,
    sp.entity_id,
    'Not Submitted',
    NULL,                -- explicit NULL overrides the now() default
    NULL                 -- no score yet
  FROM biz_001.student_profiles sp
  JOIN biz_001.entities e ON e.id = sp.entity_id
  WHERE sp.class             = NEW.class
    AND sp.section           = NEW.section
    AND sp.enrollment_status = 'enrolled'
    AND e.status             = 'active';

  RETURN NEW;
END;
$$;

-- ────────────────────────────────────────────────────────────────────
-- 2. The trigger
-- ────────────────────────────────────────────────────────────────────
-- AFTER INSERT (not BEFORE) so the homework row's homework_id is
-- finalized before the cascade runs.
-- FOR EACH ROW so the function runs per inserted row, not per statement.

DROP TRIGGER IF EXISTS homework_autocreate_submissions ON biz_001.homework;

CREATE TRIGGER homework_autocreate_submissions
  AFTER INSERT ON biz_001.homework
  FOR EACH ROW
  EXECUTE FUNCTION biz_001.create_homework_submission_grid();

COMMIT;

-- ────────────────────────────────────────────────────────────────────
-- POST-DEPLOY VERIFICATION (run AFTER the migration commits)
-- ────────────────────────────────────────────────────────────────────
-- These queries are NOT inside the BEGIN/COMMIT above. Run them
-- separately to confirm the trigger works.
--
-- (a) Confirm the trigger exists and is wired:
--
--   SELECT trigger_name, event_manipulation, action_timing, action_statement
--   FROM information_schema.triggers
--   WHERE event_object_schema = 'biz_001'
--     AND event_object_table  = 'homework';
--
-- Expected: 1 row, homework_autocreate_submissions, INSERT, AFTER
--
-- (b) Live test — insert a throwaway homework, verify 8 Not Submitted
--     rows appear, then clean up. CLEAN UP IMMEDIATELY after testing.
--
--   -- Insert test row (no homework_id supplied; will be auto-generated):
--   INSERT INTO biz_001.homework
--     (business_id, title, subject_id, class, section, assigned_by,
--      assigned_date, due_date, homework_type, max_score, is_active, academic_year)
--   SELECT
--     'biz_001', 'TRIGGER TEST — DELETE ME', subject_id, '9', 'A', NULL,
--     CURRENT_DATE, CURRENT_DATE + 3, 'Worksheet', 10, true, '2026-27'
--   FROM biz_001.subjects
--   WHERE class = '9' AND academic_year = '2026-27' AND is_active = true
--   LIMIT 1
--   RETURNING homework_id;
--   -- Note the returned homework_id (call it X)
--
--   -- Verify 8 Not Submitted rows appeared:
--   SELECT COUNT(*) FROM biz_001.homework_submissions
--   WHERE homework_id = '<X>' AND status = 'Not Submitted';
--   -- Expected: 8
--
--   -- Clean up:
--   DELETE FROM biz_001.homework_submissions WHERE homework_id = '<X>';
--   DELETE FROM biz_001.homework            WHERE homework_id = '<X>';
