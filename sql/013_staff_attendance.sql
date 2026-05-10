-- =========================================================================
-- Migration 013: staff_attendance (daily, all staff)
-- =========================================================================
-- Section 4 Table 3 of 6 (Light Integration Scoping Doc)
-- 
-- Purpose: One row per staff member per day. Captures check-in/check-out 
--          times, status (Present/Absent/Half Day/Leave), leave type 
--          (Casual/Sick/Earned/Unpaid), and late minutes. Universal across 
--          teaching and non-teaching staff.
--
-- Conditional CHECK: leave_type required when status='Leave', NULL otherwise.
--
-- Deployed: May 11, 2026 (production main branch)
-- =========================================================================

BEGIN;

CREATE TABLE biz_001.staff_attendance (
  id                UUID         NOT NULL DEFAULT gen_random_uuid(),
  business_id       TEXT         NOT NULL DEFAULT 'biz_001',
  staff_entity_id   UUID         NOT NULL,
  attendance_date   DATE         NOT NULL,
  check_in_time     TIME         NULL,
  check_out_time    TIME         NULL,
  status            TEXT         NOT NULL,
  leave_type        TEXT         NULL,
  late_minutes      INT          NULL,
  notes             TEXT         NULL,
  marked_by         UUID         NULL,
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT staff_attendance_pkey PRIMARY KEY (id),
  CONSTRAINT staff_attendance_unique 
    UNIQUE (business_id, staff_entity_id, attendance_date),
  CONSTRAINT staff_attendance_staff_fk 
    FOREIGN KEY (staff_entity_id) REFERENCES biz_001.entities(id),
  CONSTRAINT staff_attendance_marked_by_fk 
    FOREIGN KEY (marked_by) REFERENCES biz_001.entities(id),
  CONSTRAINT staff_attendance_status_check 
    CHECK (status IN ('Present', 'Absent', 'Half Day', 'Leave')),
  CONSTRAINT staff_attendance_leave_type_check 
    CHECK (
      (status = 'Leave' AND leave_type IN ('Casual', 'Sick', 'Earned', 'Unpaid'))
      OR
      (status != 'Leave' AND leave_type IS NULL)
    )
);

CREATE INDEX staff_attendance_staff_date_idx 
  ON biz_001.staff_attendance(staff_entity_id, attendance_date DESC);

CREATE INDEX staff_attendance_date_idx 
  ON biz_001.staff_attendance(attendance_date);

CREATE TRIGGER staff_attendance_set_updated_at
  BEFORE UPDATE ON biz_001.staff_attendance
  FOR EACH ROW
  EXECUTE FUNCTION biz_001.set_updated_at();

ALTER TABLE biz_001.staff_attendance ENABLE ROW LEVEL SECURITY;

COMMIT;
