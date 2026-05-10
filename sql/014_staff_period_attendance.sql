-- =========================================================================
-- Migration 014: staff_period_attendance (period-level, teachers only)
-- =========================================================================
-- Section 4 Table 4 of 6 (Light Integration Scoping Doc)
-- 
-- Purpose: One row per teacher per period per day. Captures whether the 
--          teacher was present for each scheduled period. Pairs with 
--          staff_attendance (daily check-in) — separate concerns.
--
-- Status options: Present / Absent. Substitutions captured via 
-- substituted_by FK to entities.id.
--
-- Deployed: May 11, 2026 (production main branch)
-- =========================================================================

BEGIN;

CREATE TABLE biz_001.staff_period_attendance (
  id                  UUID         NOT NULL DEFAULT gen_random_uuid(),
  business_id         TEXT         NOT NULL DEFAULT 'biz_001',
  teacher_entity_id   UUID         NOT NULL,
  attendance_date     DATE         NOT NULL,
  period_number       INT          NOT NULL,
  status              TEXT         NOT NULL,
  substituted_by      UUID         NULL,
  notes               TEXT         NULL,
  marked_by           UUID         NULL,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT staff_period_attendance_pkey PRIMARY KEY (id),
  CONSTRAINT staff_period_attendance_unique 
    UNIQUE (business_id, teacher_entity_id, attendance_date, period_number),
  CONSTRAINT staff_period_attendance_teacher_fk 
    FOREIGN KEY (teacher_entity_id) REFERENCES biz_001.entities(id),
  CONSTRAINT staff_period_attendance_substituted_fk 
    FOREIGN KEY (substituted_by) REFERENCES biz_001.entities(id),
  CONSTRAINT staff_period_attendance_marked_by_fk 
    FOREIGN KEY (marked_by) REFERENCES biz_001.entities(id),
  CONSTRAINT staff_period_attendance_status_check 
    CHECK (status IN ('Present', 'Absent')),
  CONSTRAINT staff_period_attendance_period_check 
    CHECK (period_number >= 1)
);

CREATE INDEX staff_period_attendance_teacher_date_idx 
  ON biz_001.staff_period_attendance(teacher_entity_id, attendance_date DESC);

CREATE INDEX staff_period_attendance_date_idx 
  ON biz_001.staff_period_attendance(attendance_date);

CREATE TRIGGER staff_period_attendance_set_updated_at
  BEFORE UPDATE ON biz_001.staff_period_attendance
  FOR EACH ROW
  EXECUTE FUNCTION biz_001.set_updated_at();

ALTER TABLE biz_001.staff_period_attendance ENABLE ROW LEVEL SECURITY;

COMMIT;
