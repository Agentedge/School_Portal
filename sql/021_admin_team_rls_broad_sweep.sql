-- =====================================================
-- M021: Broad admin_team RLS sweep for biz_001
-- =====================================================
-- Purpose:
--   Add admin_team RLS policies to 21 operational tables that were
--   missing them. Closes the gap revealed by the May 13 RLS audit.
--
-- Mirrors the canonical pattern established by M016-M020:
--   biz_001.get_user_role() = 'Admin_team'::text, bound to public role.
--
-- Categorization:
--   FOR ALL    (19 tables) — admin reads and writes
--   FOR SELECT (2 tables)  — audit_log, agent_signals_archive
--
-- Skipped: teacher_subjects_backup_20260506 (backup table)
--
-- Pre-flight verified May 13: RLS already enabled on all target tables.
-- ENABLE ROW LEVEL SECURITY lines are idempotent no-ops, kept for safety.
--
-- Author: Bhargav Avadhanula, with Claude as CTO
-- Date:   2026-05-13
-- =====================================================

BEGIN;

-- ============ Section 1: FOR ALL policies (19 tables) ============

-- student_profiles
ALTER TABLE biz_001.student_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY student_profiles_admin_team_all ON biz_001.student_profiles
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- attendance
ALTER TABLE biz_001.attendance ENABLE ROW LEVEL SECURITY;
CREATE POLICY attendance_admin_team_all ON biz_001.attendance
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- marks
ALTER TABLE biz_001.marks ENABLE ROW LEVEL SECURITY;
CREATE POLICY marks_admin_team_all ON biz_001.marks
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- subjects
ALTER TABLE biz_001.subjects ENABLE ROW LEVEL SECURITY;
CREATE POLICY subjects_admin_team_all ON biz_001.subjects
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- fee_payments
ALTER TABLE biz_001.fee_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY fee_payments_admin_team_all ON biz_001.fee_payments
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- fee_structure
ALTER TABLE biz_001.fee_structure ENABLE ROW LEVEL SECURITY;
CREATE POLICY fee_structure_admin_team_all ON biz_001.fee_structure
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- performance_observations
ALTER TABLE biz_001.performance_observations ENABLE ROW LEVEL SECURITY;
CREATE POLICY performance_observations_admin_team_all ON biz_001.performance_observations
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- interventions
ALTER TABLE biz_001.interventions ENABLE ROW LEVEL SECURITY;
CREATE POLICY interventions_admin_team_all ON biz_001.interventions
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- homework
ALTER TABLE biz_001.homework ENABLE ROW LEVEL SECURITY;
CREATE POLICY homework_admin_team_all ON biz_001.homework
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- homework_submissions
ALTER TABLE biz_001.homework_submissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY homework_submissions_admin_team_all ON biz_001.homework_submissions
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- teacher_profiles
ALTER TABLE biz_001.teacher_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY teacher_profiles_admin_team_all ON biz_001.teacher_profiles
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- teacher_assignments
ALTER TABLE biz_001.teacher_assignments ENABLE ROW LEVEL SECURITY;
CREATE POLICY teacher_assignments_admin_team_all ON biz_001.teacher_assignments
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- teacher_subjects
ALTER TABLE biz_001.teacher_subjects ENABLE ROW LEVEL SECURITY;
CREATE POLICY teacher_subjects_admin_team_all ON biz_001.teacher_subjects
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- academic_calendar
ALTER TABLE biz_001.academic_calendar ENABLE ROW LEVEL SECURITY;
CREATE POLICY academic_calendar_admin_team_all ON biz_001.academic_calendar
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- events
ALTER TABLE biz_001.events ENABLE ROW LEVEL SECURITY;
CREATE POLICY events_admin_team_all ON biz_001.events
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- documents
ALTER TABLE biz_001.documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY documents_admin_team_all ON biz_001.documents
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- transactions
ALTER TABLE biz_001.transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY transactions_admin_team_all ON biz_001.transactions
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- house_points
ALTER TABLE biz_001.house_points ENABLE ROW LEVEL SECURITY;
CREATE POLICY house_points_admin_team_all ON biz_001.house_points
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- agent_signals
ALTER TABLE biz_001.agent_signals ENABLE ROW LEVEL SECURITY;
CREATE POLICY agent_signals_admin_team_all ON biz_001.agent_signals
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text)
  WITH CHECK (biz_001.get_user_role() = 'Admin_team'::text);

-- ============ Section 2: FOR SELECT policies (2 tables) ============

-- audit_log
ALTER TABLE biz_001.audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_log_admin_team_select ON biz_001.audit_log
  FOR SELECT TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text);

-- agent_signals_archive
ALTER TABLE biz_001.agent_signals_archive ENABLE ROW LEVEL SECURITY;
CREATE POLICY agent_signals_archive_admin_team_select ON biz_001.agent_signals_archive
  FOR SELECT TO public
  USING (biz_001.get_user_role() = 'Admin_team'::text);

COMMIT;
