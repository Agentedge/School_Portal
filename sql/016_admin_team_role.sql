-- ============================================================================
-- Migration 016 — Add AdminTeam role to ae_platform.user_roles role enum
-- ============================================================================
-- Purpose
-- -------
-- Per the Light Integration Scoping Doc (Section 2, locked May 10, 2026),
-- AgentEdge Unified introduces a second role: AdminTeam ("Empowered
-- Operational Tier"). This migration adds 'admin_team' as a permitted value
-- on the role CHECK constraint of ae_platform.user_roles.
--
-- Storage is lowercase snake_case to match existing convention; the
-- get_user_role() helper applies INITCAP, so 'admin_team' becomes
-- 'Admin_Team' in RLS policy comparisons.
--
-- The existing 'admin' value is preserved (origin pre-dates Light
-- Integration session history; filed as Pre-Wave-2 backlog B-10:
-- "Investigate origin of unused 'admin' role; drop if confirmed dead").
--
-- Date: May 11, 2026
-- ============================================================================

BEGIN;

ALTER TABLE ae_platform.user_roles
  DROP CONSTRAINT user_roles_role_check;

ALTER TABLE ae_platform.user_roles
  ADD CONSTRAINT user_roles_role_check
  CHECK (role IN (
    'principal',
    'admin',         -- legacy, unused; preserved per Path A
    'teacher',
    'parent',
    'student',
    'admin_team'     -- NEW: AgentEdge Unified AdminTeam role
  ));

COMMIT;

-- ============================================================================
-- Verification (run after COMMIT):
-- ----------------------------------------------------------------------------
-- SELECT con.conname AS constraint_name,
--        pg_get_constraintdef(con.oid) AS definition
-- FROM pg_constraint con
-- JOIN pg_class cls ON cls.oid = con.conrelid
-- JOIN pg_namespace nsp ON nsp.oid = cls.relnamespace
-- WHERE nsp.nspname = 'ae_platform'
--   AND cls.relname = 'user_roles'
--   AND con.contype = 'c';
--
-- Expected: definition shows 6 values including 'admin_team'.
-- ============================================================================
