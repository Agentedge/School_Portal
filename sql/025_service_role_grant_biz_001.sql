-- Migration 025: service_role read-only grant on biz_001
-- ----------------------------------------------------------------------------
-- Purpose: The Mitra proxy (AgentEdge_Unified) reads biz_001 server-side using
--          the Supabase SECRET key, which maps to the Postgres `service_role`.
--          That role had no grants on biz_001, so this gives it READ-ONLY
--          access (SELECT only -- no INSERT/UPDATE/DELETE).
-- Run as:  a privileged role (postgres / the SQL Editor default).
-- Reuse:   Run once per business schema. For school #2, copy this file and
--          replace every biz_001 with biz_002.
-- Safe to re-run (idempotent): re-granting an existing privilege is a no-op.
-- ----------------------------------------------------------------------------

GRANT USAGE ON SCHEMA biz_001 TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA biz_001 TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA biz_001 GRANT SELECT ON TABLES TO service_role;
