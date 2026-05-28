-- =====================================================
-- M022: Seed student transactional data for 5 student-derived agents
-- =====================================================
-- Purpose:
--   Boost foundation data (attendance, marks) and seed empty tables
--   (communication_logs, communication_preferences, interventions,
--    performance_observations, homework, homework_submissions) and
--   gap-fill fee_payments for 5 students missing payment history.
--
--   Unlocks wiring of FeeAlert, AttritionGuard, AttendanceFlag,
--   ResultPredictor, ParentBridge.
--
-- Scope: biz_001 only. All 8 Class 9 Section A students.
--
-- Strategy:
--   - Deterministic MOD-based formulas for attendance/marks (reproducible).
--   - Explicit VALUES for low-volume tables (handcrafted realism).
--   - ON CONFLICT DO NOTHING where UNIQUE constraints exist (idempotent).
--   - Atomic transaction (BEGIN/COMMIT) — all or nothing.
--
-- Re-run safety:
--   - attendance, marks, performance_observations, homework, homework_submissions,
--     communication_preferences are idempotent (UNIQUE-anchored ON CONFLICT).
--   - fee_payments, communication_logs, interventions have no UNIQUE constraints
--     → re-running would duplicate. DO NOT re-run this migration without
--     first deleting these rows manually.
--
-- Author: Bhargav Avadhanula, with Claude as CTO
-- Date:   2026-05-13
-- =====================================================

BEGIN;

-- =====================================================================
-- 1. Boost attendance: +208 rows (period_number=1, two non-overlap windows)
-- =====================================================================
-- Existing data covers 2026-04-25 to 2026-05-01 (periods 1 and 2).
-- New windows: 2026-04-06 to 2026-04-24, and 2026-05-02 to 2026-05-12.
-- Skips Sundays (Telangana state schools open Mon-Sat).
-- Status distribution via MOD formula: ~80% Present, ~7% Late, ~3% Half Day,
-- ~3% Leave, ~7% Absent.
WITH dates AS (
  SELECT d::date AS d FROM generate_series('2026-04-06'::date, '2026-04-24'::date, '1 day'::interval) d
  UNION
  SELECT d::date FROM generate_series('2026-05-02'::date, '2026-05-12'::date, '1 day'::interval) d
),
weekdays AS (
  SELECT d FROM dates WHERE EXTRACT(DOW FROM d) <> 0  -- 0 = Sunday
),
students AS (
  SELECT student_id, student_no FROM (VALUES
    ('e1000001-0000-0000-0000-000000000001'::uuid, 1),
    ('e1000002-0000-0000-0000-000000000001'::uuid, 2),
    ('e1000003-0000-0000-0000-000000000001'::uuid, 3),
    ('e1000004-0000-0000-0000-000000000001'::uuid, 4),
    ('e1000005-0000-0000-0000-000000000001'::uuid, 5),
    ('e1000006-0000-0000-0000-000000000001'::uuid, 6),
    ('e1000007-0000-0000-0000-000000000001'::uuid, 7),
    ('e1000008-0000-0000-0000-000000000001'::uuid, 8)
  ) AS s(student_id, student_no)
)
INSERT INTO biz_001.attendance (student_id, class, section, date, status, period_number)
SELECT
  s.student_id,
  '9',
  'A',
  w.d,
  CASE
    WHEN MOD(EXTRACT(DAY FROM w.d)::int * s.student_no + EXTRACT(MONTH FROM w.d)::int, 30) < 24 THEN 'Present'
    WHEN MOD(EXTRACT(DAY FROM w.d)::int * s.student_no + EXTRACT(MONTH FROM w.d)::int, 30) < 26 THEN 'Late'
    WHEN MOD(EXTRACT(DAY FROM w.d)::int * s.student_no + EXTRACT(MONTH FROM w.d)::int, 30) = 26 THEN 'Half Day'
    WHEN MOD(EXTRACT(DAY FROM w.d)::int * s.student_no + EXTRACT(MONTH FROM w.d)::int, 30) = 27 THEN 'Leave'
    ELSE 'Absent'
  END,
  1
FROM students s CROSS JOIN weekdays w
ON CONFLICT (student_id, date, period_number) DO NOTHING;


-- =====================================================================
-- 2. Boost marks: +88 rows (Unit Test 2 + Class Test, different exam_types
-- =====================================================================
-- Existing 11 rows are all "Unit Test 1" on 2026-05-06/07. Avoid collision
-- by using different exam_types (Unit Test 2 on 2026-05-08, Class Test on
-- 2026-04-29). Scores via MOD formula, ~40-90% of max.
WITH students AS (
  SELECT student_id, student_no FROM (VALUES
    ('e1000001-0000-0000-0000-000000000001'::uuid, 1),
    ('e1000002-0000-0000-0000-000000000001'::uuid, 2),
    ('e1000003-0000-0000-0000-000000000001'::uuid, 3),
    ('e1000004-0000-0000-0000-000000000001'::uuid, 4),
    ('e1000005-0000-0000-0000-000000000001'::uuid, 5),
    ('e1000006-0000-0000-0000-000000000001'::uuid, 6),
    ('e1000007-0000-0000-0000-000000000001'::uuid, 7),
    ('e1000008-0000-0000-0000-000000000001'::uuid, 8)
  ) AS s(student_id, student_no)
),
exams AS (
  SELECT subject_id, subject_no, max_marks_val, exam_type_val, exam_date_val FROM (VALUES
    -- Unit Test 2: all 7 subjects
    ('da361ef4-d65d-49c2-ae11-1262c584b52f'::uuid, 1, 80::numeric, 'Unit Test 2', '2026-05-08'::date),
    ('1b2179ea-7bd3-4c03-8791-53be80340500'::uuid, 2, 80::numeric, 'Unit Test 2', '2026-05-08'::date),
    ('e96f47c5-39d7-4bc9-b591-1f50b9ac1c61'::uuid, 3, 80::numeric, 'Unit Test 2', '2026-05-08'::date),
    ('bdde6895-c643-47a0-a513-4552aa6e42b7'::uuid, 4, 100::numeric, 'Unit Test 2', '2026-05-08'::date),
    ('7c15b92f-e0f2-4657-9333-06ae71a12999'::uuid, 5, 80::numeric, 'Unit Test 2', '2026-05-08'::date),
    ('e33509af-fd5d-4cc7-90cf-9d5c0e0adc3c'::uuid, 6, 80::numeric, 'Unit Test 2', '2026-05-08'::date),
    ('88cb81b5-a584-46ac-a60b-194d56bf387b'::uuid, 7, 80::numeric, 'Unit Test 2', '2026-05-08'::date),
    -- Class Test: 4 core subjects
    ('bdde6895-c643-47a0-a513-4552aa6e42b7'::uuid, 4, 30::numeric, 'Class Test', '2026-04-29'::date),
    ('1b2179ea-7bd3-4c03-8791-53be80340500'::uuid, 2, 30::numeric, 'Class Test', '2026-04-29'::date),
    ('88cb81b5-a584-46ac-a60b-194d56bf387b'::uuid, 7, 30::numeric, 'Class Test', '2026-04-29'::date),
    ('7c15b92f-e0f2-4657-9333-06ae71a12999'::uuid, 5, 30::numeric, 'Class Test', '2026-04-29'::date)
  ) AS e(subject_id, subject_no, max_marks_val, exam_type_val, exam_date_val)
)
INSERT INTO biz_001.marks (student_id, subject_id, class, section, exam_type, exam_date, score, max_marks)
SELECT
  s.student_id,
  e.subject_id,
  '9',
  'A',
  e.exam_type_val,
  e.exam_date_val,
  ROUND((MOD(s.student_no * 7 + e.subject_no * 11, 50) + 40)::numeric * e.max_marks_val / 100, 0),
  e.max_marks_val
FROM students s CROSS JOIN exams e
ON CONFLICT (student_id, subject_id, exam_type, exam_date) DO NOTHING;


-- =====================================================================
-- 3. Fee payments: +12 rows for the 5 students missing payment history
-- =====================================================================
-- Existing 25 rows cover 3 students. Seed for: Priya (2), Lakshmi (4),
-- Sai Kiran (5), Divya (6), Sneha (8). 2-3 payments each across 2025-26.
-- Mix of Tuition (51000001), Annual (51000002), Exam (51000003), Transport (51000004).
INSERT INTO biz_001.fee_payments (student_id, fee_structure_id, parent_id, amount_paid, payment_date, payment_mode, period_month, period_year, academic_year)
VALUES
  -- Priya Sharma (e2 / f2)
  ('e1000002-0000-0000-0000-000000000001', '51000001-0000-0000-0000-000000000001', 'f1000002-0000-0000-0000-000000000001', 3000, '2025-07-05', 'UPI', 7, 2025, '2025-26'),
  ('e1000002-0000-0000-0000-000000000001', '51000001-0000-0000-0000-000000000001', 'f1000002-0000-0000-0000-000000000001', 3000, '2025-10-08', 'UPI', 10, 2025, '2025-26'),
  ('e1000002-0000-0000-0000-000000000001', '51000004-0000-0000-0000-000000000001', 'f1000002-0000-0000-0000-000000000001', 800, '2025-08-12', 'Cash', 8, 2025, '2025-26'),
  -- Lakshmi Devi Konda (e4 / f4)
  ('e1000004-0000-0000-0000-000000000001', '51000001-0000-0000-0000-000000000001', 'f1000004-0000-0000-0000-000000000001', 3000, '2025-08-03', 'Cash', 8, 2025, '2025-26'),
  ('e1000004-0000-0000-0000-000000000001', '51000002-0000-0000-0000-000000000001', 'f1000004-0000-0000-0000-000000000001', 12000, '2025-06-15', 'NEFT', 6, 2025, '2025-26'),
  -- Sai Kiran Vemuri (e5 / f5) - light history to signal "at risk"
  ('e1000005-0000-0000-0000-000000000001', '51000001-0000-0000-0000-000000000001', 'f1000005-0000-0000-0000-000000000001', 3000, '2025-07-08', 'UPI', 7, 2025, '2025-26'),
  ('e1000005-0000-0000-0000-000000000001', '51000001-0000-0000-0000-000000000001', 'f1000005-0000-0000-0000-000000000001', 3000, '2025-09-05', 'UPI', 9, 2025, '2025-26'),
  -- Divya Nair (e6 / f6)
  ('e1000006-0000-0000-0000-000000000001', '51000001-0000-0000-0000-000000000001', 'f1000006-0000-0000-0000-000000000001', 3000, '2025-08-10', 'Cash', 8, 2025, '2025-26'),
  ('e1000006-0000-0000-0000-000000000001', '51000001-0000-0000-0000-000000000001', 'f1000006-0000-0000-0000-000000000001', 3000, '2025-11-12', 'UPI', 11, 2025, '2025-26'),
  ('e1000006-0000-0000-0000-000000000001', '51000003-0000-0000-0000-000000000001', 'f1000006-0000-0000-0000-000000000001', 500, '2025-09-15', 'Cash', 9, 2025, '2025-26'),
  -- Sneha Patel (e8 / f8)
  ('e1000008-0000-0000-0000-000000000001', '51000001-0000-0000-0000-000000000001', 'f1000008-0000-0000-0000-000000000001', 3000, '2025-07-04', 'UPI', 7, 2025, '2025-26'),
  ('e1000008-0000-0000-0000-000000000001', '51000004-0000-0000-0000-000000000001', 'f1000008-0000-0000-0000-000000000001', 800, '2025-09-08', 'Cash', 9, 2025, '2025-26');


-- =====================================================================
-- 4. Communication preferences: 8 rows, one per parent
-- =====================================================================
-- WhatsApp dominant (matches India SME reality). Mix of Telugu / Hindi /
-- English. Sai Kiran's parent opts out of marketing. Sneha's holidays on.
INSERT INTO biz_001.communication_preferences (parent_entity_id, preferred_channel, preferred_language, opt_in_marketing, holiday_mode)
VALUES
  ('f1000001-0000-0000-0000-000000000001', 'whatsapp', 'telugu',  true,  false),
  ('f1000002-0000-0000-0000-000000000001', 'whatsapp', 'hindi',   true,  false),
  ('f1000003-0000-0000-0000-000000000001', 'sms',      'english', true,  false),
  ('f1000004-0000-0000-0000-000000000001', 'whatsapp', 'telugu',  true,  false),
  ('f1000005-0000-0000-0000-000000000001', 'whatsapp', 'telugu',  false, false),
  ('f1000006-0000-0000-0000-000000000001', 'email',    'english', true,  false),
  ('f1000007-0000-0000-0000-000000000001', 'whatsapp', 'telugu',  true,  false),
  ('f1000008-0000-0000-0000-000000000001', 'whatsapp', 'english', true,  true)
ON CONFLICT (business_id, parent_entity_id) DO NOTHING;


-- =====================================================================
-- 5. Communication logs: 20 rows across agents/channels/categories
-- =====================================================================
-- Mix of fee_reminder, attendance, academic, event categories. Mostly
-- delivered, some sent/pending. Spans 2026-04-15 to 2026-05-12.
INSERT INTO biz_001.communication_logs (recipient_entity_id, sender_agent, channel, language, category, subject, message_content, sent_at, delivery_status)
VALUES
  ('f1000001-0000-0000-0000-000000000001', 'FeeAlert',       'whatsapp', 'telugu',  'fee_reminder', 'Fee due',           'Tuition fee for May 2026 is due on 10-May-2026.',           '2026-05-08 09:00:00+05:30', 'delivered'),
  ('f1000001-0000-0000-0000-000000000001', 'AttendanceFlag', 'whatsapp', 'telugu',  'attendance',   'Absent today',      'Ravi was absent from school today (12-May-2026).',          '2026-05-12 14:30:00+05:30', 'delivered'),
  ('f1000002-0000-0000-0000-000000000001', 'AttendanceFlag', 'whatsapp', 'hindi',   'attendance',   'Late arrival',      'Priya arrived late today (10-May-2026).',                   '2026-05-10 09:45:00+05:30', 'sent'),
  ('f1000003-0000-0000-0000-000000000001', 'ParentBridge',   'sms',      'english', 'academic',     'Test marks',        'Mohammed scored 65/80 in Unit Test 2 Mathematics.',         '2026-05-09 11:00:00+05:30', 'delivered'),
  ('f1000004-0000-0000-0000-000000000001', 'FeeAlert',       'whatsapp', 'telugu',  'fee_reminder', 'Outstanding balance','Tuition fee balance: Rs. 9,000 pending.',                  '2026-05-05 10:00:00+05:30', 'delivered'),
  ('f1000005-0000-0000-0000-000000000001', 'FeeAlert',       'whatsapp', 'telugu',  'fee_reminder', 'Fee overdue',       'Tuition fee for April overdue. Please clear.',              '2026-05-02 09:30:00+05:30', 'delivered'),
  ('f1000005-0000-0000-0000-000000000001', 'AttritionGuard', 'whatsapp', 'telugu',  'academic',     'Performance concern','Sai Kiran has shown declining marks in last 2 tests.',     '2026-05-11 16:00:00+05:30', 'delivered'),
  ('f1000006-0000-0000-0000-000000000001', 'AttendanceFlag', 'email',    'english', 'attendance',   'Weekly summary',    'Divya - attendance 90% this week.',                         '2026-05-09 18:00:00+05:30', 'delivered'),
  ('f1000007-0000-0000-0000-000000000001', 'FeeAlert',       'whatsapp', 'telugu',  'fee_reminder', 'Fee receipt',       'Fee payment of Rs. 3000 received. Thank you.',              '2026-04-15 11:30:00+05:30', 'delivered'),
  ('f1000008-0000-0000-0000-000000000001', 'AttritionGuard', 'whatsapp', 'english', 'academic',     'Improvement',       'Sneha has improved 15% over last test cycle.',              '2026-05-09 17:00:00+05:30', 'delivered'),
  ('f1000001-0000-0000-0000-000000000001', 'ParentBridge',   'whatsapp', 'telugu',  'event',        'Annual Day',        'Annual Day on 25-May-2026. RSVP by 18-May.',                '2026-05-10 12:00:00+05:30', 'delivered'),
  ('f1000002-0000-0000-0000-000000000001', 'ParentBridge',   'whatsapp', 'hindi',   'event',        'Annual Day',        'Annual Day on 25-May-2026. RSVP by 18-May.',                '2026-05-10 12:00:00+05:30', 'delivered'),
  ('f1000003-0000-0000-0000-000000000001', 'ParentBridge',   'sms',      'english', 'event',        'Annual Day',        'Annual Day on 25-May-2026. RSVP by 18-May.',                '2026-05-10 12:00:00+05:30', 'delivered'),
  ('f1000004-0000-0000-0000-000000000001', 'ParentBridge',   'whatsapp', 'telugu',  'event',        'Annual Day',        'Annual Day on 25-May-2026. RSVP by 18-May.',                '2026-05-10 12:00:00+05:30', 'pending'),
  ('f1000006-0000-0000-0000-000000000001', 'ParentBridge',   'email',    'english', 'event',        'Annual Day',        'Annual Day on 25-May-2026. RSVP by 18-May.',                '2026-05-10 12:00:00+05:30', 'delivered'),
  ('f1000007-0000-0000-0000-000000000001', 'ParentBridge',   'whatsapp', 'telugu',  'event',        'Annual Day',        'Annual Day on 25-May-2026. RSVP by 18-May.',                '2026-05-10 12:00:00+05:30', 'delivered'),
  ('f1000008-0000-0000-0000-000000000001', 'ParentBridge',   'whatsapp', 'english', 'event',        'Annual Day',        'Annual Day on 25-May-2026. RSVP by 18-May.',                '2026-05-10 12:00:00+05:30', 'delivered'),
  ('f1000004-0000-0000-0000-000000000001', 'AttendanceFlag', 'whatsapp', 'telugu',  'attendance',   'Half day',          'Lakshmi left school after lunch on 08-May.',                '2026-05-08 14:00:00+05:30', 'delivered'),
  ('f1000007-0000-0000-0000-000000000001', 'FeeAlert',       'whatsapp', 'telugu',  'fee_reminder', 'Transport fee',     'Transport fee for May 2026 due 10-May.',                    '2026-05-07 09:00:00+05:30', 'delivered'),
  ('f1000003-0000-0000-0000-000000000001', 'AttritionGuard', 'sms',      'english', 'academic',     'Concern - Math',    'Mohammed scored 55% in Math - below class average.',        '2026-05-11 16:30:00+05:30', 'sent');


-- =====================================================================
-- 6. Performance observations: 24 rows (~3 per student across subjects)
-- =====================================================================
-- Mix of behaviours: Excellent (top performers), Good (steady), Satisfactory
-- (middle), Needs Improvement (at-risk like Mohammed, Sai Kiran).
INSERT INTO biz_001.performance_observations (student_id, class, section, subject_id, observation_date, participation, classwork_score, behaviour, homework_status, notes)
VALUES
  -- Ravi Kumar Reddy (e1)
  ('e1000001-0000-0000-0000-000000000001', '9', 'A', 'bdde6895-c643-47a0-a513-4552aa6e42b7', '2026-04-28', 4, 8.5, 'Good',              'Submitted',     'Active in problem solving'),
  ('e1000001-0000-0000-0000-000000000001', '9', 'A', '1b2179ea-7bd3-4c03-8791-53be80340500', '2026-05-05', 3, 7.0, 'Satisfactory',      'Late',          'Improvement in reading speed'),
  ('e1000001-0000-0000-0000-000000000001', '9', 'A', '88cb81b5-a584-46ac-a60b-194d56bf387b', '2026-05-08', 4, 8.0, 'Good',              'Submitted',     'Excellent essay submission'),
  -- Priya Sharma (e2)
  ('e1000002-0000-0000-0000-000000000001', '9', 'A', '1b2179ea-7bd3-4c03-8791-53be80340500', '2026-04-29', 5, 9.0, 'Excellent',         'Submitted',     'Top scorer in vocabulary test'),
  ('e1000002-0000-0000-0000-000000000001', '9', 'A', 'bdde6895-c643-47a0-a513-4552aa6e42b7', '2026-05-06', 4, 8.5, 'Good',              'Submitted',     'Algebra strong'),
  ('e1000002-0000-0000-0000-000000000001', '9', 'A', 'da361ef4-d65d-49c2-ae11-1262c584b52f', '2026-05-09', 4, 8.0, 'Good',              'Submitted',     'Active in lab'),
  -- Mohammed Farhan Shaik (e3) - at risk
  ('e1000003-0000-0000-0000-000000000001', '9', 'A', 'bdde6895-c643-47a0-a513-4552aa6e42b7', '2026-04-28', 2, 5.0, 'Needs Improvement', 'Not Submitted', 'Struggling with quadratics - needs extra help'),
  ('e1000003-0000-0000-0000-000000000001', '9', 'A', '1b2179ea-7bd3-4c03-8791-53be80340500', '2026-05-05', 3, 6.5, 'Satisfactory',      'Incomplete',    'Vocabulary improving'),
  ('e1000003-0000-0000-0000-000000000001', '9', 'A', '7c15b92f-e0f2-4657-9333-06ae71a12999', '2026-05-11', 2, 5.5, 'Needs Improvement', 'Late',          'Distracted in class'),
  -- Lakshmi Devi Konda (e4)
  ('e1000004-0000-0000-0000-000000000001', '9', 'A', '88cb81b5-a584-46ac-a60b-194d56bf387b', '2026-04-30', 5, 9.5, 'Excellent',         'Submitted',     'Class leader in Telugu literature'),
  ('e1000004-0000-0000-0000-000000000001', '9', 'A', 'e33509af-fd5d-4cc7-90cf-9d5c0e0adc3c', '2026-05-07', 4, 8.0, 'Good',              'Submitted',     'Strong on history dates'),
  ('e1000004-0000-0000-0000-000000000001', '9', 'A', 'bdde6895-c643-47a0-a513-4552aa6e42b7', '2026-05-09', 3, 7.5, 'Good',              'Submitted',     'Geometry pickup'),
  -- Sai Kiran Vemuri (e5) - at risk
  ('e1000005-0000-0000-0000-000000000001', '9', 'A', 'bdde6895-c643-47a0-a513-4552aa6e42b7', '2026-04-29', 2, 4.5, 'Needs Improvement', 'Not Submitted', 'Falling behind - parent meeting needed'),
  ('e1000005-0000-0000-0000-000000000001', '9', 'A', '1b2179ea-7bd3-4c03-8791-53be80340500', '2026-05-04', 2, 5.0, 'Needs Improvement', 'Late',          'Below class average'),
  ('e1000005-0000-0000-0000-000000000001', '9', 'A', '7c15b92f-e0f2-4657-9333-06ae71a12999', '2026-05-08', 3, 6.0, 'Satisfactory',      'Incomplete',    'Trying but needs more practice'),
  -- Divya Nair (e6)
  ('e1000006-0000-0000-0000-000000000001', '9', 'A', '1b2179ea-7bd3-4c03-8791-53be80340500', '2026-04-30', 5, 9.0, 'Excellent',         'Submitted',     'Excellent comprehension'),
  ('e1000006-0000-0000-0000-000000000001', '9', 'A', 'da361ef4-d65d-49c2-ae11-1262c584b52f', '2026-05-06', 4, 8.5, 'Good',              'Submitted',     'Lab work commendable'),
  ('e1000006-0000-0000-0000-000000000001', '9', 'A', 'bdde6895-c643-47a0-a513-4552aa6e42b7', '2026-05-11', 4, 8.0, 'Good',              'Submitted',     'Improvement in geometry'),
  -- Arjun Naidu (e7)
  ('e1000007-0000-0000-0000-000000000001', '9', 'A', 'e33509af-fd5d-4cc7-90cf-9d5c0e0adc3c', '2026-04-28', 4, 7.5, 'Good',              'Submitted',     'Good understanding of civics'),
  ('e1000007-0000-0000-0000-000000000001', '9', 'A', 'bdde6895-c643-47a0-a513-4552aa6e42b7', '2026-05-05', 3, 7.0, 'Good',              'Submitted',     'Consistent performer'),
  ('e1000007-0000-0000-0000-000000000001', '9', 'A', '7c15b92f-e0f2-4657-9333-06ae71a12999', '2026-05-09', 4, 8.0, 'Good',              'Submitted',     'Lab participation up'),
  -- Sneha Patel (e8) - improver
  ('e1000008-0000-0000-0000-000000000001', '9', 'A', '1b2179ea-7bd3-4c03-8791-53be80340500', '2026-04-30', 4, 8.5, 'Good',              'Submitted',     'Steady progress'),
  ('e1000008-0000-0000-0000-000000000001', '9', 'A', 'bdde6895-c643-47a0-a513-4552aa6e42b7', '2026-05-07', 5, 9.0, 'Excellent',         'Submitted',     'Top of class in functions'),
  ('e1000008-0000-0000-0000-000000000001', '9', 'A', 'da361ef4-d65d-49c2-ae11-1262c584b52f', '2026-05-10', 4, 8.0, 'Good',              'Submitted',     'Lab leader')
ON CONFLICT (student_id, subject_id, observation_date) DO NOTHING;


-- =====================================================================
-- 7. Homework: 6 assignments (one per major subject)
-- =====================================================================
-- Spread across 2026-05-04 to 2026-05-09 with due dates through 2026-05-14.
-- Hardcoded UUIDs so re-runs are idempotent via ON CONFLICT.
INSERT INTO biz_001.homework (homework_id, title, subject_id, class, section, assigned_date, due_date, homework_type, max_score)
VALUES
  ('72000001-0000-0000-0000-000000000001', 'Algebra Practice Set 2',     'bdde6895-c643-47a0-a513-4552aa6e42b7', '9', 'A', '2026-05-04', '2026-05-08', 'Worksheet', 20),
  ('72000002-0000-0000-0000-000000000001', 'Essay on Climate Change',    '1b2179ea-7bd3-4c03-8791-53be80340500', '9', 'A', '2026-05-05', '2026-05-10', 'Project',   30),
  ('72000003-0000-0000-0000-000000000001', 'Chapter 3 Quiz - Telugu',    '88cb81b5-a584-46ac-a60b-194d56bf387b', '9', 'A', '2026-05-06', '2026-05-09', 'Quiz',      10),
  ('72000004-0000-0000-0000-000000000001', 'Cell Biology Reading',       'da361ef4-d65d-49c2-ae11-1262c584b52f', '9', 'A', '2026-05-07', '2026-05-11', 'Reading',   10),
  ('72000005-0000-0000-0000-000000000001', 'Indian Geography Project',   'e33509af-fd5d-4cc7-90cf-9d5c0e0adc3c', '9', 'A', '2026-05-08', '2026-05-14', 'Project',   30),
  ('72000006-0000-0000-0000-000000000001', 'Chemistry Worksheet',        '7c15b92f-e0f2-4657-9333-06ae71a12999', '9', 'A', '2026-05-09', '2026-05-12', 'Worksheet', 20)
ON CONFLICT (homework_id) DO NOTHING;


-- =====================================================================
-- 8. Homework submissions: 28 rows (~65% submission rate)
-- =====================================================================
-- Pattern: top performers submit on time and get graded. Strugglers
-- (Mohammed e3, Sai Kiran e5) miss some. Recent ones still ungraded.
INSERT INTO biz_001.homework_submissions (homework_id, student_id, submitted_at, score, status)
VALUES
  -- Algebra Practice Set 2 (HW1, due 2026-05-08, max 20)
  ('72000001-0000-0000-0000-000000000001', 'e1000001-0000-0000-0000-000000000001', '2026-05-07 18:00:00+05:30', 16,   'Graded'),
  ('72000001-0000-0000-0000-000000000001', 'e1000002-0000-0000-0000-000000000001', '2026-05-08 09:00:00+05:30', 18,   'Graded'),
  ('72000001-0000-0000-0000-000000000001', 'e1000003-0000-0000-0000-000000000001', '2026-05-09 10:00:00+05:30', 10,   'Late'),
  ('72000001-0000-0000-0000-000000000001', 'e1000004-0000-0000-0000-000000000001', '2026-05-08 14:00:00+05:30', 15,   'Graded'),
  ('72000001-0000-0000-0000-000000000001', 'e1000005-0000-0000-0000-000000000001', NULL,                        NULL, 'Not Submitted'),
  ('72000001-0000-0000-0000-000000000001', 'e1000006-0000-0000-0000-000000000001', '2026-05-08 11:30:00+05:30', 17,   'Graded'),
  ('72000001-0000-0000-0000-000000000001', 'e1000007-0000-0000-0000-000000000001', '2026-05-08 16:00:00+05:30', 14,   'Graded'),
  ('72000001-0000-0000-0000-000000000001', 'e1000008-0000-0000-0000-000000000001', '2026-05-07 19:00:00+05:30', 19,   'Graded'),
  -- Essay on Climate Change (HW2, due 2026-05-10, max 30)
  ('72000002-0000-0000-0000-000000000001', 'e1000001-0000-0000-0000-000000000001', '2026-05-09 17:00:00+05:30', 22,   'Graded'),
  ('72000002-0000-0000-0000-000000000001', 'e1000002-0000-0000-0000-000000000001', '2026-05-10 10:00:00+05:30', 28,   'Graded'),
  ('72000002-0000-0000-0000-000000000001', 'e1000003-0000-0000-0000-000000000001', NULL,                        NULL, 'Not Submitted'),
  ('72000002-0000-0000-0000-000000000001', 'e1000004-0000-0000-0000-000000000001', '2026-05-10 09:00:00+05:30', 27,   'Graded'),
  ('72000002-0000-0000-0000-000000000001', 'e1000005-0000-0000-0000-000000000001', '2026-05-11 14:00:00+05:30', 15,   'Late'),
  ('72000002-0000-0000-0000-000000000001', 'e1000006-0000-0000-0000-000000000001', '2026-05-10 08:00:00+05:30', 29,   'Graded'),
  ('72000002-0000-0000-0000-000000000001', 'e1000008-0000-0000-0000-000000000001', '2026-05-09 20:00:00+05:30', 26,   'Graded'),
  -- Chapter 3 Quiz - Telugu (HW3, due 2026-05-09, max 10)
  ('72000003-0000-0000-0000-000000000001', 'e1000001-0000-0000-0000-000000000001', '2026-05-09 12:00:00+05:30', 8,    'Graded'),
  ('72000003-0000-0000-0000-000000000001', 'e1000002-0000-0000-0000-000000000001', '2026-05-09 11:00:00+05:30', 9,    'Graded'),
  ('72000003-0000-0000-0000-000000000001', 'e1000004-0000-0000-0000-000000000001', '2026-05-09 10:30:00+05:30', 10,   'Graded'),
  ('72000003-0000-0000-0000-000000000001', 'e1000005-0000-0000-0000-000000000001', NULL,                        NULL, 'Not Submitted'),
  ('72000003-0000-0000-0000-000000000001', 'e1000007-0000-0000-0000-000000000001', '2026-05-09 13:00:00+05:30', 7,    'Graded'),
  -- Cell Biology Reading (HW4, due 2026-05-11, max 10)
  ('72000004-0000-0000-0000-000000000001', 'e1000002-0000-0000-0000-000000000001', '2026-05-11 14:00:00+05:30', 9,    'Graded'),
  ('72000004-0000-0000-0000-000000000001', 'e1000006-0000-0000-0000-000000000001', '2026-05-11 11:00:00+05:30', 10,   'Graded'),
  ('72000004-0000-0000-0000-000000000001', 'e1000008-0000-0000-0000-000000000001', '2026-05-11 15:00:00+05:30', 8,    'Graded'),
  -- Indian Geography Project (HW5, due 2026-05-14, max 30, in progress)
  ('72000005-0000-0000-0000-000000000001', 'e1000004-0000-0000-0000-000000000001', '2026-05-12 09:00:00+05:30', NULL, 'Submitted'),
  ('72000005-0000-0000-0000-000000000001', 'e1000007-0000-0000-0000-000000000001', '2026-05-11 17:00:00+05:30', NULL, 'Submitted'),
  -- Chemistry Worksheet (HW6, due 2026-05-12, max 20)
  ('72000006-0000-0000-0000-000000000001', 'e1000001-0000-0000-0000-000000000001', '2026-05-12 12:00:00+05:30', NULL, 'Submitted'),
  ('72000006-0000-0000-0000-000000000001', 'e1000002-0000-0000-0000-000000000001', '2026-05-12 10:00:00+05:30', NULL, 'Submitted'),
  ('72000006-0000-0000-0000-000000000001', 'e1000005-0000-0000-0000-000000000001', NULL,                        NULL, 'Not Submitted')
ON CONFLICT (homework_id, student_id) DO NOTHING;


-- =====================================================================
-- 9. Interventions: 15 rows (platform-level agent action log)
-- =====================================================================
-- Mix of auto_executed (system actions), approved (admin OK'd), pending
-- (awaiting decision). Tied to fee/attendance/attrition/parent flows.
INSERT INTO biz_001.interventions (agent_name, action_type, action_payload, status, decided_by, decided_at)
VALUES
  ('FeeAlert',       'send_reminder',     '{"recipient": "f1000005-0000-0000-0000-000000000001", "channel": "whatsapp", "template": "fee_overdue", "amount": 3000}'::jsonb,                          'auto_executed', 'system', '2026-05-02 09:30:00+05:30'),
  ('FeeAlert',       'send_reminder',     '{"recipient": "f1000004-0000-0000-0000-000000000001", "channel": "whatsapp", "template": "balance_pending", "amount": 9000}'::jsonb,                      'auto_executed', 'system', '2026-05-05 10:00:00+05:30'),
  ('FeeAlert',       'send_reminder',     '{"recipient": "f1000001-0000-0000-0000-000000000001", "channel": "whatsapp", "template": "fee_due_soon", "amount": 3000}'::jsonb,                         'auto_executed', 'system', '2026-05-08 09:00:00+05:30'),
  ('AttendanceFlag', 'send_alert',        '{"recipient": "f1000001-0000-0000-0000-000000000001", "channel": "whatsapp", "reason": "absent_today", "date": "2026-05-12"}'::jsonb,                     'auto_executed', 'system', '2026-05-12 14:30:00+05:30'),
  ('AttendanceFlag', 'send_alert',        '{"recipient": "f1000002-0000-0000-0000-000000000001", "channel": "whatsapp", "reason": "late_arrival", "date": "2026-05-10"}'::jsonb,                     'auto_executed', 'system', '2026-05-10 09:45:00+05:30'),
  ('AttendanceFlag', 'send_alert',        '{"recipient": "f1000004-0000-0000-0000-000000000001", "channel": "whatsapp", "reason": "half_day", "date": "2026-05-08"}'::jsonb,                         'auto_executed', 'system', '2026-05-08 14:00:00+05:30'),
  ('AttritionGuard', 'send_alert',        '{"recipient": "f1000003-0000-0000-0000-000000000001", "student": "Mohammed Farhan Shaik", "trigger": "declining_marks", "subject": "Mathematics"}'::jsonb, 'approved',      'admin',  '2026-05-11 16:30:00+05:30'),
  ('AttritionGuard', 'send_alert',        '{"recipient": "f1000005-0000-0000-0000-000000000001", "student": "Sai Kiran Vemuri", "trigger": "performance_concern", "trend": "declining"}'::jsonb,     'approved',      'admin',  '2026-05-11 16:00:00+05:30'),
  ('AttritionGuard', 'flag_for_review',   '{"student": "e1000005-0000-0000-0000-000000000001", "risk_level": "high", "factors": ["attendance", "marks", "homework"]}'::jsonb,                        'pending',       NULL,     NULL),
  ('AttritionGuard', 'flag_for_review',   '{"student": "e1000003-0000-0000-0000-000000000001", "risk_level": "medium", "factors": ["marks", "behaviour"]}'::jsonb,                                   'pending',       NULL,     NULL),
  ('ParentBridge',   'send_message',      '{"recipients": ["f1000001", "f1000002", "f1000003", "f1000004", "f1000006", "f1000007", "f1000008"], "category": "event", "subject": "Annual Day"}'::jsonb,'auto_executed', 'system', '2026-05-10 12:00:00+05:30'),
  ('ResultPredictor','send_alert',        '{"recipient": "f1000008-0000-0000-0000-000000000001", "student": "Sneha Patel", "prediction": "improvement", "confidence": 0.85}'::jsonb,                  'auto_executed', 'system', '2026-05-09 17:00:00+05:30'),
  ('RouteWatch',     'send_alert',        '{"recipient": "admin", "route": "RT03", "issue": "late_pickup", "count": 3}'::jsonb,                                                                       'pending',       NULL,     NULL),
  ('FeeAlert',       'escalate',          '{"recipient": "admin", "student": "e1000005-0000-0000-0000-000000000001", "reason": "no_response_3_reminders"}'::jsonb,                                    'pending',       NULL,     NULL),
  ('AttendanceFlag', 'weekly_summary',    '{"students_at_risk": 2, "absences_total": 6, "late_arrivals": 4}'::jsonb,                                                                                  'auto_executed', 'system', '2026-05-09 18:00:00+05:30');


COMMIT;

