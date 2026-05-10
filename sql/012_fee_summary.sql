-- =========================================================================
-- Migration 012: fee_summary (with trigger function and recompute helper)
-- =========================================================================
-- Section 4 Table 1 of 6 (Light Integration Scoping Doc)
-- 
-- Purpose: Monthly snapshot per (year, month, fee_type) of expected vs 
--          actual fee collection. Trigger keeps collected_amount and 
--          paid_student_count in sync with fee_payments INSERTs.
--          target_amount and expected_student_count are stored snapshots
--          set by application layer or seed data.
--
-- Includes:
--   - fee_summary table (12 columns)
--   - refresh_fee_summary_for_payment() trigger function (INSERT-only for v1)
--   - recompute_fee_summary(year, month, fee_type) manual helper
--
-- Pre-Wave-2 backlog: extend trigger to handle UPDATE/DELETE
--
-- Deployed: May 11, 2026 (production main branch)
-- =========================================================================

BEGIN;

CREATE TABLE biz_001.fee_summary (
  id                       UUID         NOT NULL DEFAULT gen_random_uuid(),
  business_id              TEXT         NOT NULL DEFAULT 'biz_001',
  year                     INT          NOT NULL,
  month                    INT          NOT NULL,
  fee_type                 TEXT         NOT NULL,
  target_amount            NUMERIC(12,2) NULL,
  collected_amount         NUMERIC(12,2) NOT NULL DEFAULT 0,
  expected_student_count   INT          NULL,
  paid_student_count       INT          NOT NULL DEFAULT 0,
  notes                    TEXT         NULL,
  created_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT fee_summary_pkey PRIMARY KEY (id),
  CONSTRAINT fee_summary_unique UNIQUE (business_id, year, month, fee_type),
  CONSTRAINT fee_summary_month_check CHECK (month >= 1 AND month <= 12)
);

CREATE INDEX fee_summary_business_year_month_idx 
  ON biz_001.fee_summary(business_id, year, month);

CREATE TRIGGER fee_summary_set_updated_at
  BEFORE UPDATE ON biz_001.fee_summary
  FOR EACH ROW
  EXECUTE FUNCTION biz_001.set_updated_at();

ALTER TABLE biz_001.fee_summary ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION biz_001.refresh_fee_summary_for_payment()
RETURNS TRIGGER AS $$
DECLARE
  v_year INT;
  v_month INT;
  v_fee_type TEXT;
BEGIN
  IF TG_OP != 'INSERT' THEN
    RETURN NEW;
  END IF;

  v_year := COALESCE(NEW.period_year, EXTRACT(YEAR FROM NEW.payment_date)::INT);
  v_month := COALESCE(NEW.period_month, EXTRACT(MONTH FROM NEW.payment_date)::INT);

  SELECT fs.fee_type INTO v_fee_type
  FROM biz_001.fee_structure fs
  WHERE fs.fee_structure_id = NEW.fee_structure_id;

  IF v_fee_type IS NULL THEN
    RETURN NEW;
  END IF;

  INSERT INTO biz_001.fee_summary (
    business_id, year, month, fee_type, 
    collected_amount, paid_student_count
  )
  SELECT 
    'biz_001', v_year, v_month, v_fee_type,
    COALESCE(SUM(fp.amount_paid), 0),
    COUNT(DISTINCT fp.student_id)
  FROM biz_001.fee_payments fp
  JOIN biz_001.fee_structure fs ON fs.fee_structure_id = fp.fee_structure_id
  WHERE fp.business_id = 'biz_001'
    AND COALESCE(fp.period_year, EXTRACT(YEAR FROM fp.payment_date)::INT) = v_year
    AND COALESCE(fp.period_month, EXTRACT(MONTH FROM fp.payment_date)::INT) = v_month
    AND fs.fee_type = v_fee_type
  ON CONFLICT (business_id, year, month, fee_type) 
  DO UPDATE SET 
    collected_amount = EXCLUDED.collected_amount,
    paid_student_count = EXCLUDED.paid_student_count,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER fee_payments_refresh_summary
  AFTER INSERT ON biz_001.fee_payments
  FOR EACH ROW
  EXECUTE FUNCTION biz_001.refresh_fee_summary_for_payment();

CREATE OR REPLACE FUNCTION biz_001.recompute_fee_summary(
  p_year INT, 
  p_month INT, 
  p_fee_type TEXT
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO biz_001.fee_summary (
    business_id, year, month, fee_type,
    collected_amount, paid_student_count
  )
  SELECT 
    'biz_001', p_year, p_month, p_fee_type,
    COALESCE(SUM(fp.amount_paid), 0),
    COUNT(DISTINCT fp.student_id)
  FROM biz_001.fee_payments fp
  JOIN biz_001.fee_structure fs ON fs.fee_structure_id = fp.fee_structure_id
  WHERE fp.business_id = 'biz_001'
    AND COALESCE(fp.period_year, EXTRACT(YEAR FROM fp.payment_date)::INT) = p_year
    AND COALESCE(fp.period_month, EXTRACT(MONTH FROM fp.payment_date)::INT) = p_month
    AND fs.fee_type = p_fee_type
  ON CONFLICT (business_id, year, month, fee_type)
  DO UPDATE SET 
    collected_amount = EXCLUDED.collected_amount,
    paid_student_count = EXCLUDED.paid_student_count,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

COMMIT;
