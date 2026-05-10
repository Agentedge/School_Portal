-- =========================================================================
-- Migration 010: communication_preferences
-- =========================================================================
-- Section 4 Table 2 of 6 (Light Integration Scoping Doc)
-- 
-- Purpose: Per-family communication preferences (channel, language, opt-ins,
--          holiday mode, quiet hours). Used by ParentBridge and other agents.
-- 
-- Anchor: parent entity in biz_001.entities (entity_type = 'Parent').
--         One preferences row per family unit.
--
-- Deployed: May 10, 2026 (production main branch)
-- =========================================================================

BEGIN;

-- Helper function for updated_at trigger (idempotent — reused by 011-015)
CREATE OR REPLACE FUNCTION biz_001.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- The table itself
CREATE TABLE biz_001.communication_preferences (
  id                  UUID         NOT NULL DEFAULT gen_random_uuid(),
  business_id         TEXT         NOT NULL DEFAULT 'biz_001',
  parent_entity_id    UUID         NOT NULL,
  preferred_channel   TEXT         NOT NULL DEFAULT 'whatsapp',
  preferred_language  TEXT         NOT NULL DEFAULT 'english',
  opt_in_marketing    BOOLEAN      NOT NULL DEFAULT TRUE,
  holiday_mode        BOOLEAN      NOT NULL DEFAULT FALSE,
  quiet_hours_start   TIME         NULL,
  quiet_hours_end     TIME         NULL,
  notes               TEXT         NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT communication_preferences_pkey PRIMARY KEY (id),
  CONSTRAINT communication_preferences_parent_unique 
    UNIQUE (business_id, parent_entity_id),
  CONSTRAINT communication_preferences_parent_fk 
    FOREIGN KEY (parent_entity_id) 
    REFERENCES biz_001.entities(id) 
    ON DELETE CASCADE,
  CONSTRAINT communication_preferences_channel_check 
    CHECK (preferred_channel IN ('whatsapp', 'sms', 'email', 'call')),
  CONSTRAINT communication_preferences_language_check 
    CHECK (preferred_language IN ('english', 'telugu', 'hindi'))
);

-- Index for common business_id lookups
CREATE INDEX comm_prefs_business_idx 
  ON biz_001.communication_preferences(business_id);

-- updated_at trigger
CREATE TRIGGER comm_prefs_set_updated_at
  BEFORE UPDATE ON biz_001.communication_preferences
  FOR EACH ROW
  EXECUTE FUNCTION biz_001.set_updated_at();

-- Enable RLS (real policies in migration 017)
ALTER TABLE biz_001.communication_preferences ENABLE ROW LEVEL SECURITY;

COMMIT;
