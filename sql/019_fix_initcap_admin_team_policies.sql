-- Migration 019: Fix INITCAP-related typo in M017 admin_team policies
-- Drop and re-create the 6 admin_team policies from M017 with the correct
-- role string. PostgreSQL INITCAP('admin_team') returns 'Admin_team'
-- (lowercase t), not 'Admin_Team' — underscore is NOT a word separator.
-- M017 created these checking for 'Admin_Team' (capital T), which never
-- matched, silently filtering all rows for admin_team users.
-- Created May 12, 2026 — formalized from in-session SQL run during B-30 sweep.

BEGIN;

-- 1. admissions (FOR ALL)
DROP POLICY admissions_admin_team_all ON biz_001.admissions;
CREATE POLICY admissions_admin_team_all ON biz_001.admissions
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team')
  WITH CHECK (biz_001.get_user_role() = 'Admin_team');

-- 2. communication_logs (FOR SELECT)
DROP POLICY communication_logs_admin_team_select ON biz_001.communication_logs;
CREATE POLICY communication_logs_admin_team_select ON biz_001.communication_logs
  FOR SELECT TO public
  USING (biz_001.get_user_role() = 'Admin_team');

-- 3. communication_preferences (FOR ALL)
DROP POLICY communication_preferences_admin_team_all ON biz_001.communication_preferences;
CREATE POLICY communication_preferences_admin_team_all ON biz_001.communication_preferences
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team')
  WITH CHECK (biz_001.get_user_role() = 'Admin_team');

-- 4. fee_summary (FOR ALL)
DROP POLICY fee_summary_admin_team_all ON biz_001.fee_summary;
CREATE POLICY fee_summary_admin_team_all ON biz_001.fee_summary
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team')
  WITH CHECK (biz_001.get_user_role() = 'Admin_team');

-- 5. staff_attendance (FOR ALL)
DROP POLICY staff_attendance_admin_team_all ON biz_001.staff_attendance;
CREATE POLICY staff_attendance_admin_team_all ON biz_001.staff_attendance
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team')
  WITH CHECK (biz_001.get_user_role() = 'Admin_team');

-- 6. staff_period_attendance (FOR ALL)
DROP POLICY staff_period_attendance_admin_team_all ON biz_001.staff_period_attendance;
CREATE POLICY staff_period_attendance_admin_team_all ON biz_001.staff_period_attendance
  FOR ALL TO public
  USING (biz_001.get_user_role() = 'Admin_team')
  WITH CHECK (biz_001.get_user_role() = 'Admin_team');

COMMIT;
