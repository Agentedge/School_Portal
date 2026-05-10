-- =========================================================================
-- Migration 015: admissions (prospect lifecycle tracking)
-- =========================================================================
-- Section 4 Table 6 of 6 (Light Integration Scoping Doc)
-- 
-- Purpose: Track every prospect (potential family) from initial inquiry 
--          through admission decision and enrollment. Self-contained — 
--          prospects only become entities at first outreach (prospect_entity_id) 
--          or enrollment (converted_student_id).
--
-- Lifecycle (via status column): inquiry -> contacted -> visited -> applied 
-- -> admitted -> enrolled (or rejected/dropped at any point).
--
-- AdmissionRadar agent's primary data source.
--
-- Deployed: May 11, 2026 (production main branch)
-- =========================================================================

BEGIN;

CREATE TABLE biz_001.admissions (
  id                       UUID         NOT NULL DEFAULT gen_random_uuid(),
  business_id              TEXT         NOT NULL DEFAULT 'biz_001',
  parent_name              TEXT         NOT NULL,
  parent_phone             TEXT         NOT NULL,
  parent_email             TEXT         NULL,
  parent_address           TEXT         NULL,
  student_name             TEXT         NOT NULL,
  student_dob              DATE         NULL,
  student_gender           TEXT         NULL,
  current_school           TEXT         NULL,
  target_class             TEXT         NOT NULL,
  target_academic_year     TEXT         NOT NULL DEFAULT '2026-27',
  source                   TEXT         NULL,
  status                   TEXT         NOT NULL DEFAULT 'inquiry',
  inquiry_date             DATE         NOT NULL DEFAULT CURRENT_DATE,
  visit_scheduled_at       TIMESTAMPTZ  NULL,
  visit_completed_at       TIMESTAMPTZ  NULL,
  decision_date            DATE         NULL,
  decision_made_by         UUID         NULL,
  prospect_entity_id       UUID         NULL,
  converted_student_id     UUID         NULL,
  notes                    TEXT         NULL,
  created_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT admissions_pkey PRIMARY KEY (id),
  CONSTRAINT admissions_unique 
    UNIQUE (business_id, parent_phone, student_name, target_academic_year),
  CONSTRAINT admissions_decision_made_by_fk 
    FOREIGN KEY (decision_made_by) REFERENCES biz_001.entities(id),
  CONSTRAINT admissions_prospect_fk 
    FOREIGN KEY (prospect_entity_id) REFERENCES biz_001.entities(id),
  CONSTRAINT admissions_converted_student_fk 
    FOREIGN KEY (converted_student_id) REFERENCES biz_001.entities(id),
  CONSTRAINT admissions_status_check 
    CHECK (status IN ('inquiry', 'contacted', 'visited', 'applied', 
                      'admitted', 'enrolled', 'rejected', 'dropped')),
  CONSTRAINT admissions_source_check 
    CHECK (source IS NULL OR source IN ('walk_in', 'referral', 'website', 
                                         'newspaper', 'social_media')),
  CONSTRAINT admissions_gender_check 
    CHECK (student_gender IS NULL OR student_gender IN ('Male', 'Female', 'Other'))
);

CREATE INDEX admissions_status_idx 
  ON biz_001.admissions(status);

CREATE INDEX admissions_inquiry_date_idx 
  ON biz_001.admissions(inquiry_date DESC);

CREATE INDEX admissions_parent_phone_idx 
  ON biz_001.admissions(parent_phone);

CREATE TRIGGER admissions_set_updated_at
  BEFORE UPDATE ON biz_001.admissions
  FOR EACH ROW
  EXECUTE FUNCTION biz_001.set_updated_at();

ALTER TABLE biz_001.admissions ENABLE ROW LEVEL SECURITY;

COMMIT;
