-- ============================================================
-- 007_pre_wave_1_cleanup_part_1.sql
-- ============================================================
-- Captures three changes applied to dev Supabase between
-- May 7-8, 2026, as part of Pre-Wave-1 hardening.
--
-- (1) Class value normalisation — 39 rows across 3 tables
--     standardised from 'Class 9' to '9'  (Pre-Wave-1 #1)
-- (2) Drop orphaned biz_002.user_roles table — architectural
--     drift cleanup; correct location is ae_platform.user_roles
--     (Pre-Wave-1 #13)
-- (3) Fix biz_001.log_audit() to preserve old_data on UPDATE
--     (Pre-Wave-1 #9 — original backlog description was
--     inaccurate; actual fix is in this file)
--
-- All operations are idempotent: safe to re-run.
-- ============================================================


-- ------------------------------------------------------------
-- (1) Class normalisation across 3 tables
-- Idempotent: WHERE clause matches nothing on subsequent runs
-- ------------------------------------------------------------

UPDATE biz_001.attendance
SET class = '9', updated_at = NOW()
WHERE class = 'Class 9';
-- Expected: 29 rows on first run, 0 on subsequent runs

UPDATE biz_001.fee_structure
SET class = '9', updated_at = NOW()
WHERE class = 'Class 9';
-- Expected: 4 rows on first run, 0 on subsequent runs

UPDATE biz_001.teacher_subjects
SET class = '9', updated_at = NOW()
WHERE class = 'Class 9';
-- Expected: 6 rows on first run, 0 on subsequent runs


-- ------------------------------------------------------------
-- (2) Drop orphaned biz_002.user_roles
-- IF EXISTS makes this safely idempotent
-- ------------------------------------------------------------

DROP TABLE IF EXISTS biz_002.user_roles;


-- ------------------------------------------------------------
-- (3) Fix biz_001.log_audit() to preserve old_data on UPDATE
-- CREATE OR REPLACE is inherently idempotent
--
-- The change: old_data CASE clause now includes UPDATE
-- (was: TG_OP = 'DELETE'  →  now: TG_OP IN ('UPDATE', 'DELETE'))
-- Everything else identical to the prior function definition
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION biz_001.log_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_row_id UUID;
  v_data JSONB;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_data := to_jsonb(OLD);
  ELSE
    v_data := to_jsonb(NEW);
  END IF;

  -- Try to extract the row ID from whichever PK column exists
  v_row_id := COALESCE(
    (v_data->>'id')::uuid,
    (v_data->>'subject_id')::uuid,
    (v_data->>'attendance_id')::uuid,
    (v_data->>'mark_id')::uuid,
    (v_data->>'payment_id')::uuid,
    (v_data->>'fee_structure_id')::uuid,
    (v_data->>'homework_id')::uuid,
    (v_data->>'submission_id')::uuid,
    (v_data->>'assignment_id')::uuid,
    (v_data->>'calendar_id')::uuid,
    (v_data->>'teacher_subject_id')::uuid,
    (v_data->>'route_id')::uuid,
    (v_data->>'stop_id')::uuid,
    (v_data->>'student_transport_id')::uuid,
    (v_data->>'point_id')::uuid,
    gen_random_uuid()
  );

  INSERT INTO biz_001.audit_log
    (business_id, table_name, row_id, action, old_data, new_data, changed_by)
  VALUES
    ((SELECT id FROM ae_platform.businesses WHERE schema_name = 'biz_001'),
     TG_TABLE_NAME,
     v_row_id,
     TG_OP,
     CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
     CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END,
     auth.uid()
    );
  RETURN COALESCE(NEW, OLD);
END;
$function$;


-- ============================================================
-- End of migration 007
-- ============================================================
