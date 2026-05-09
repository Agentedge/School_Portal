-- ============================================================================
-- Migration 009 — Pre-Wave-1 Cleanup Part 3
-- ============================================================================
-- Purpose: Create biz_001.teacher_profiles table (mirror of student_profiles
--          shape, scaled to teacher use case)
-- Closes:  Pre-Wave-1 backlog #16
-- Idempotent: yes (CREATE TABLE IF NOT EXISTS, CREATE INDEX IF NOT EXISTS,
--             COMMENTs are inherently idempotent)
--
-- Design rationale:
--   Original build log called this "teacher_profiles asymmetry vs
--   student_profiles." On verification (May 8, 2026), the asymmetry was
--   total — no teacher_profiles table existed at all. Path A chosen: create
--   teacher_profiles to mirror student_profiles shape, with teacher-specific
--   columns (employee_code, joining_date, qualifications, employment_type,
--   employment_status) replacing student-specific ones (admission_number,
--   parent_id, academic_year, enrollment_status, fee_category, transport_mode,
--   previous_school, roll_number).
--
--   Existing teacher data lives across:
--     - entities (universal: name, contact, address, entity-level status)
--     - teacher_assignments (class, section, role, auth_user_id)
--     - teacher_subjects (subject mapping)
--   teacher_profiles fills the demographic + employment metadata gap without
--   duplicating those.
--
-- DPDP NOTE — sensitive personal data:
--   `gender` and `date_of_birth` are sensitive under India's DPDP Act 2023.
--   Adult subjects (teachers) have simpler consent paths than minors, but
--   the DPA must still cover collection. Schema added; real values must NOT
--   be migrated until DPA is signed.
--
-- Future cleanup (NOT in scope of this migration):
--   - FK constraint entity_id -> entities(id) (skipped to match the existing
--     student_profiles pattern; revisit in a future "tighten FKs" migration).
--   - audit_log trigger on UPDATE/DELETE (if biz_001 pattern requires; check
--     against student_profiles trigger setup before adding).
-- ============================================================================

CREATE TABLE IF NOT EXISTS biz_001.teacher_profiles (
  id                 uuid        PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id        text        NOT NULL    DEFAULT 'biz_001'::text,
  entity_id          uuid        NOT NULL,
  employee_code      text,
  joining_date       date,
  qualifications     text,
  employment_type    text,
  photo_url          text,
  gender             text,
  date_of_birth      date,
  blood_group        text,
  employment_status  text        NOT NULL    DEFAULT 'active',
  metadata           jsonb       DEFAULT '{}'::jsonb,
  created_at         timestamptz DEFAULT now(),
  updated_at         timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_teacher_profiles_entity_id
  ON biz_001.teacher_profiles(entity_id);

-- ─── Table and column documentation ─────────────────────────────────────────
COMMENT ON TABLE biz_001.teacher_profiles IS
  'Teacher demographic + employment metadata. Mirrors student_profiles shape. Identity/contact in entities; assignments in teacher_assignments; subjects in teacher_subjects.';

COMMENT ON COLUMN biz_001.teacher_profiles.employee_code IS
  'School-internal teacher ID (analogous to admission_number for students)';
COMMENT ON COLUMN biz_001.teacher_profiles.joining_date IS
  'Date the teacher joined this school (analogous to admission_date for students)';
COMMENT ON COLUMN biz_001.teacher_profiles.qualifications IS
  'Free-text qualifications (e.g., "B.Ed, M.Sc Mathematics"). Could move to structured array later.';
COMMENT ON COLUMN biz_001.teacher_profiles.employment_type IS
  'Standard values: full-time/part-time/contract/visiting. Free-text for now.';
COMMENT ON COLUMN biz_001.teacher_profiles.photo_url IS
  'URL to teacher photo, typically a Supabase Storage path';
COMMENT ON COLUMN biz_001.teacher_profiles.gender IS
  'DPDP-sensitive. Standard values: Male/Female/Other/Prefer not to say. Populate only with consent.';
COMMENT ON COLUMN biz_001.teacher_profiles.date_of_birth IS
  'DPDP-sensitive. Used for age verification, leave eligibility, retirement planning.';
COMMENT ON COLUMN biz_001.teacher_profiles.blood_group IS
  'For emergency/medical contexts. Free-text (e.g., "O+", "AB-").';
COMMENT ON COLUMN biz_001.teacher_profiles.employment_status IS
  'Teacher-level state: active/on-leave/resigned/terminated. Distinct from entity-level entities.status.';
