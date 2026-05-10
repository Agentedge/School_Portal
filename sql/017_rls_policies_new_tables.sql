-- ============================================================================
-- Migration 017 — RLS policies for the 6 new tables (010-015)
-- ============================================================================
-- Purpose
-- -------
-- Tables created by migrations 010-015 have RLS enabled but NO policies.
-- Every authenticated user is currently denied; only service_role bypasses.
-- This migration writes per-role policies per the locked permission matrix
-- from the Light Integration Scoping Doc (Section 2, May 10) and the matrix
-- design phase of this session (May 11).
--
-- Roles (storage / INITCAP comparison value):
--   principal    -> 'Principal'
--   admin_team   -> 'Admin_Team'    (added in migration 016)
--   teacher      -> 'Teacher'
--   parent       -> 'Parent'
--   student      -> 'Student'
--   admin        -> 'Admin'         (legacy, unused; B-10)
--
-- Helper functions (already deployed):
--   biz_001.get_user_role()         -> INITCAP'd role string
--   biz_001.get_own_entity_id()     -> logged-in user's entity id
--
-- 18 policies across 6 tables.
--
-- Date: May 11, 2026
-- ============================================================================

BEGIN;

-- ============================================================================
-- SECTION 1 : communication_preferences (parent-scoped table)
-- ============================================================================

CREATE POLICY communication_preferences_principal_all
  ON biz_001.communication_preferences FOR ALL
  USING      (biz_001.get_user_role() = 'Principal')
  WITH CHECK (biz_001.get_user_role() = 'Principal');

CREATE POLICY communication_preferences_admin_team_all
  ON biz_001.communication_preferences FOR ALL
  USING      (biz_001.get_user_role() = 'Admin_Team')
  WITH CHECK (biz_001.get_user_role() = 'Admin_Team');

CREATE POLICY communication_preferences_parent_own
  ON biz_001.communication_preferences FOR ALL
  USING (
    biz_001.get_user_role() = 'Parent'
    AND parent_entity_id = biz_001.get_own_entity_id()
  )
  WITH CHECK (
    biz_001.get_user_role() = 'Parent'
    AND parent_entity_id = biz_001.get_own_entity_id()
  );

-- ============================================================================
-- SECTION 2 : communication_logs (audit trail; SELECT-only for users)
-- ============================================================================

CREATE POLICY communication_logs_principal_select
  ON biz_001.communication_logs FOR SELECT
  USING (biz_001.get_user_role() = 'Principal');

CREATE POLICY communication_logs_admin_team_select
  ON biz_001.communication_logs FOR SELECT
  USING (biz_001.get_user_role() = 'Admin_Team');

CREATE POLICY communication_logs_teacher_select
  ON biz_001.communication_logs FOR SELECT
  USING (
    biz_001.get_user_role() = 'Teacher'
    AND recipient_entity_id = biz_001.get_own_entity_id()
  );

CREATE POLICY communication_logs_parent_select
  ON biz_001.communication_logs FOR SELECT
  USING (
    biz_001.get_user_role() = 'Parent'
    AND recipient_entity_id = biz_001.get_own_entity_id()
  );

CREATE POLICY communication_logs_student_select
  ON biz_001.communication_logs FOR SELECT
  USING (
    biz_001.get_user_role() = 'Student'
    AND recipient_entity_id = biz_001.get_own_entity_id()
  );

-- ============================================================================
-- SECTION 3 : fee_summary (aggregated; Principal + AdminTeam only)
-- ============================================================================

CREATE POLICY fee_summary_principal_all
  ON biz_001.fee_summary FOR ALL
  USING      (biz_001.get_user_role() = 'Principal')
  WITH CHECK (biz_001.get_user_role() = 'Principal');

CREATE POLICY fee_summary_admin_team_all
  ON biz_001.fee_summary FOR ALL
  USING      (biz_001.get_user_role() = 'Admin_Team')
  WITH CHECK (biz_001.get_user_role() = 'Admin_Team');

-- ============================================================================
-- SECTION 4 : staff_attendance (HR; Teacher reads own row only)
-- ============================================================================

CREATE POLICY staff_attendance_principal_all
  ON biz_001.staff_attendance FOR ALL
  USING      (biz_001.get_user_role() = 'Principal')
  WITH CHECK (biz_001.get_user_role() = 'Principal');

CREATE POLICY staff_attendance_admin_team_all
  ON biz_001.staff_attendance FOR ALL
  USING      (biz_001.get_user_role() = 'Admin_Team')
  WITH CHECK (biz_001.get_user_role() = 'Admin_Team');

CREATE POLICY staff_attendance_teacher_select_own
  ON biz_001.staff_attendance FOR SELECT
  USING (
    biz_001.get_user_role() = 'Teacher'
    AND staff_entity_id = biz_001.get_own_entity_id()
  );

-- ============================================================================
-- SECTION 5 : staff_period_attendance (per-period; Teacher reads own only)
-- ============================================================================

CREATE POLICY staff_period_attendance_principal_all
  ON biz_001.staff_period_attendance FOR ALL
  USING      (biz_001.get_user_role() = 'Principal')
  WITH CHECK (biz_001.get_user_role() = 'Principal');

CREATE POLICY staff_period_attendance_admin_team_all
  ON biz_001.staff_period_attendance FOR ALL
  USING      (biz_001.get_user_role() = 'Admin_Team')
  WITH CHECK (biz_001.get_user_role() = 'Admin_Team');

CREATE POLICY staff_period_attendance_teacher_select_own
  ON biz_001.staff_period_attendance FOR SELECT
  USING (
    biz_001.get_user_role() = 'Teacher'
    AND teacher_entity_id = biz_001.get_own_entity_id()
  );

-- ============================================================================
-- SECTION 6 : admissions (prospect data; Principal + AdminTeam only)
-- ============================================================================

CREATE POLICY admissions_principal_all
  ON biz_001.admissions FOR ALL
  USING      (biz_001.get_user_role() = 'Principal')
  WITH CHECK (biz_001.get_user_role() = 'Principal');

CREATE POLICY admissions_admin_team_all
  ON biz_001.admissions FOR ALL
  USING      (biz_001.get_user_role() = 'Admin_Team')
  WITH CHECK (biz_001.get_user_role() = 'Admin_Team');

COMMIT;

-- ============================================================================
-- Verification (run after COMMIT):
-- ----------------------------------------------------------------------------
-- SELECT schemaname, tablename, COUNT(*) AS policy_count
-- FROM pg_policies
-- WHERE schemaname = 'biz_001'
--   AND tablename IN (
--     'communication_preferences', 'communication_logs', 'fee_summary',
--     'staff_attendance', 'staff_period_attendance', 'admissions'
--   )
-- GROUP BY schemaname, tablename
-- ORDER BY tablename;
--
-- Expected (6 rows):
--   admissions                  : 2
--   communication_logs          : 5
--   communication_preferences   : 3
--   fee_summary                 : 2
--   staff_attendance            : 3
--   staff_period_attendance     : 3
-- Total: 18 policies
-- ============================================================================
