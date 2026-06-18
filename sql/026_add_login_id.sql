-- 026_add_login_id.sql
-- Permanent human-readable login handle on entities.
-- Already applied to the live DB; this file exists so sql/ matches live.
ALTER TABLE biz_001.entities
  ADD COLUMN IF NOT EXISTS login_id text;

CREATE UNIQUE INDEX IF NOT EXISTS entities_login_id_uk
  ON biz_001.entities USING btree (business_id, login_id);
