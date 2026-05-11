-- Migration 020: admin_team RLS on entities table
-- Required for AgentEdge Unified to query staff/teacher entities for StaffPulse,
-- and (later) student entities for the students-master wiring.
-- Discovered as a silent RLS filter during StaffPulse smoke test (B-33).
-- B-33 also requires a full audit of biz_001 tables for admin_team coverage
-- before wiring any additional agents.
-- Created May 12, 2026 — formalized from in-session SQL during StaffPulse Step 4.

BEGIN;

CREATE POLICY entities_admin_team_select ON biz_001.entities
  FOR SELECT TO public
  USING (biz_001.get_user_role() = 'Admin_team');

COMMIT;
