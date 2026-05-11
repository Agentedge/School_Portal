-- Migration 018: admin_team RLS extension for transport tables
-- Adds row-level security policies for transport_routes, transport_stops,
-- and student_transport so the admin_team role can read transport data
-- in biz_001 schema. Required for the AgentEdge Unified RouteWatch agent.
-- Created May 12, 2026 — formalized from in-session SQL run during Wave A.

BEGIN;

CREATE POLICY transport_routes_admin_team_select ON biz_001.transport_routes
  FOR SELECT TO public
  USING (biz_001.get_user_role() = 'Admin_team');

CREATE POLICY transport_stops_admin_team_select ON biz_001.transport_stops
  FOR SELECT TO public
  USING (biz_001.get_user_role() = 'Admin_team');

CREATE POLICY student_transport_admin_team_select ON biz_001.student_transport
  FOR SELECT TO public
  USING (biz_001.get_user_role() = 'Admin_team');

COMMIT;
