-- ============================================================================
-- Migration 008 — Pre-Wave-1 Cleanup Part 2
-- ============================================================================
-- Purpose: Add 10 missing columns to biz_001.student_profiles
-- Closes:  Pre-Wave-1 backlog #10
-- Idempotent: yes (uses IF NOT EXISTS)
--
-- Drift corrections applied during design:
--   - Original build log listed "status" — but entities.status already exists
--     (NOT NULL, default 'active'). Renamed to enrollment_status to avoid
--     schema-level collision and to disambiguate entity-level from
--     student-level state.
--
-- DPDP NOTE — sensitive personal data:
--   `gender` and `disability_status` are sensitive under India's DPDP Act 2023.
--   Adding the columns does NOT authorize collection. Real values must NOT be
--   migrated until:
--     (a) Data Protection Agreement signed by school owner (Stephen)
--     (b) Parental consent captured for each child whose data is migrated
--     (c) Each sensitive column has a documented agent/workflow consumer
--   `disability_status` currently has NO documented consumer in any of the
--   8 Pulse agents. Column added per session decision (May 8, 2026);
--   purpose to be established before population.
--
-- Future dependencies:
--   `fee_category` is added as text. Will become FK to fee_structure when
--   Item #5 (Stephen-blocked) is unblocked. Plain text accepted as interim.
--   `transport_mode` is added as text. Standard values: bus/own/walking.
-- ============================================================================

ALTER TABLE biz_001.student_profiles
  ADD COLUMN IF NOT EXISTS roll_number       text,
  ADD COLUMN IF NOT EXISTS gender            text,
  ADD COLUMN IF NOT EXISTS photo_url         text,
  ADD COLUMN IF NOT EXISTS admission_date    date,
  ADD COLUMN IF NOT EXISTS fee_category      text,
  ADD COLUMN IF NOT EXISTS transport_mode    text,
  ADD COLUMN IF NOT EXISTS previous_school   text,
  ADD COLUMN IF NOT EXISTS disability_status text,
  ADD COLUMN IF NOT EXISTS academic_year     text,
  ADD COLUMN IF NOT EXISTS enrollment_status text NOT NULL DEFAULT 'enrolled';

-- ─── Column documentation ───────────────────────────────────────────────────
COMMENT ON COLUMN biz_001.student_profiles.roll_number IS
  'Class-level roll number, distinct from school-wide admission_number';
COMMENT ON COLUMN biz_001.student_profiles.gender IS
  'DPDP-sensitive. Standard values: Male/Female/Other/Prefer not to say. Populate only with consent.';
COMMENT ON COLUMN biz_001.student_profiles.photo_url IS
  'URL to student photo, typically a Supabase Storage path';
COMMENT ON COLUMN biz_001.student_profiles.admission_date IS
  'Date the student joined the school (admission, not academic year start)';
COMMENT ON COLUMN biz_001.student_profiles.fee_category IS
  'Free-text interim; future FK to fee_structure.category when Item #5 unblocks';
COMMENT ON COLUMN biz_001.student_profiles.transport_mode IS
  'Standard values: bus/own/walking. Free-text until transport_routes is modelled.';
COMMENT ON COLUMN biz_001.student_profiles.previous_school IS
  'Name of prior school for transfer-in students';
COMMENT ON COLUMN biz_001.student_profiles.disability_status IS
  'DPDP-sensitive. NO current consumer in 8 Pulse agents. Populate only with documented purpose + consent.';
COMMENT ON COLUMN biz_001.student_profiles.academic_year IS
  'Format: YYYY-YY (e.g., 2026-27). India academic year starts in June.';
COMMENT ON COLUMN biz_001.student_profiles.enrollment_status IS
  'Student-level state: enrolled/transferred/graduated/withdrawn. Distinct from entity-level entities.status.';
