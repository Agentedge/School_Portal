"""core/transformers.py — turns the v3 people-first workbook into database-ready
row dicts, following the Pass-A mapping (people only: teachers, parents, students
+ their academic profiles, and teacher assignments).

Pure data work — no database calls, so you can eyeball the dicts before anything
is inserted. Foreign keys (entity_id, parent_id, teacher_id) are NOT resolved
here; the loader mints the UUIDs and wires them. This module just carries the raw
lookup values (phones) under reserved '_'-prefixed keys.

DPA gate: when config['dpa_signed'] is false, the DPDP-gated STUDENT fields are
written as NULL (and dropped from jsonb metadata) so the roster can load before
the DPA is signed — attendance needs none of them. Backfill once the gate opens.
Teacher dob/gender are staff data and are not gated."""

from __future__ import annotations
import pandas as pd


# ---- small helpers -------------------------------------------------------

def _clean(v):
    """Blanks / NaN -> None so they become real NULLs downstream."""
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return None
    if isinstance(v, str):
        v = v.strip()
        return v or None
    return v


def _to_date(v):
    """Date text -> 'YYYY-MM-DD'. None stays None."""
    v = _clean(v)
    if v is None:
        return None
    return pd.to_datetime(v).date().isoformat()


def _strip_surname(father_name, surname):
    """Father Name minus the family-surname token -> the father's given name
    ('Polepally Naraiah' minus 'Polepally' -> 'Naraiah'). A single-token name, or
    a surname that isn't present, falls back to the whole Father Name."""
    fn = _clean(father_name)
    if fn is None:
        return None
    sn = _clean(surname)
    if sn:
        kept = [t for t in fn.split() if t.lower() != sn.lower()]
        if kept:
            return " ".join(kept)
    return fn


def _meta(d: dict) -> dict:
    """Drop None-valued keys from a metadata dict."""
    return {k: v for k, v in d.items() if v is not None}


def _rows(df):
    """Iterate a DataFrame's rows, or nothing if the tab is absent."""
    return df.iterrows() if df is not None else iter(())


# ---- the Pass-A transform ------------------------------------------------

def transform_all(workbook: dict, config: dict) -> dict:
    ay = config.get("academic_year", "2026-27")
    gated = set() if config.get("dpa_signed", False) else set(config.get("dpa_gated_columns", []))

    teachers_df = workbook.get("teachers")
    parents_df = workbook.get("parents")
    students_df = workbook.get("students")
    assign_df = workbook.get("teacher_assignments")

    # Subject codes per teacher phone (stashed onto the teacher entity metadata —
    # teacher_assignments has no subject column, so Option B keeps them here).
    subjects_by_phone: dict = {}
    for _, r in _rows(assign_df):
        ph, sc = _clean(r.get("Teacher Phone (lookup)")), _clean(r.get("Subject Code"))
        if ph and sc:
            subjects_by_phone.setdefault(ph, [])
            if sc not in subjects_by_phone[ph]:
                subjects_by_phone[ph].append(sc)

    # Family surname borrow: parent phone -> first linked student's Last Name.
    surname_by_phone: dict = {}
    for _, r in _rows(students_df):
        ph, ln = _clean(r.get("Parent Phone (lookup)")), _clean(r.get("Last Name"))
        if ph and ln and ph not in surname_by_phone:
            surname_by_phone[ph] = ln

    # --- TEACHERS -> entities(type=teacher) ---
    teachers = []
    for _, r in _rows(teachers_df):
        phone = _clean(r.get("Phone"))
        teachers.append({
            "entity_type": "teacher",
            "first_name": _clean(r.get("First Name")),
            "last_name": _clean(r.get("Last Name")),
            "phone": phone,
            "email": _clean(r.get("Email")),
            "whatsapp": _clean(r.get("WhatsApp Number")),
            "address": _clean(r.get("Address")),
            "metadata": _meta({
                "date_of_birth": _to_date(r.get("Date of Birth")),
                "gender": _clean(r.get("Gender")),
                "qualification": _clean(r.get("Qualification")),
                "joining_date": _to_date(r.get("Joining Date")),
                "designation": _clean(r.get("Designation")),
                "class_teacher_of": _clean(r.get("Class Teacher Of (e.g. 9A)")),
                "subject_codes": subjects_by_phone.get(phone) or None,
            }),
            "_phone": phone,
        })

    # --- PARENTS -> entities(type=parent), deduped on Primary Phone ---
    parents = []
    seen = set()
    for _, r in _rows(parents_df):
        phone = _clean(r.get("Primary Phone"))
        if phone in seen:
            continue
        seen.add(phone)
        surname = surname_by_phone.get(phone)
        parents.append({
            "entity_type": "parent",
            "first_name": _strip_surname(r.get("Father Name"), surname),  # given only
            "last_name": surname,                                          # borrowed
            "phone": phone,
            "whatsapp": _clean(r.get("WhatsApp Number")),
            "email": _clean(r.get("Email")),
            "address": _clean(r.get("Address")),
            "metadata": _meta({
                "mother_name": _clean(r.get("Mother Name")),
                "primary_contact_name": _clean(r.get("Primary Contact Name")),
                "city": _clean(r.get("City")),
                "pincode": _clean(r.get("Pincode")),
                "preferred_language": _clean(r.get("Preferred Language")),
                "sms": _clean(r.get("SMS")),
            }),
            "_phone": phone,
        })

    # --- STUDENTS -> entities(type=student) + student_profiles ---
    def gate(col, val):
        return None if col in gated else val

    students = []
    for _, r in _rows(students_df):
        profile = {
            "roll_number": _clean(r.get("Roll No")),
            "class": _clean(r.get("Class")),
            "section": _clean(r.get("Section")),
            "date_of_birth": gate("date_of_birth", _to_date(r.get("Date of Birth"))),
            "gender": gate("gender", _clean(r.get("Gender"))),
            "house": _clean(r.get("House")),
            "admission_date": _to_date(r.get("Admission Date")),
            "admission_number": _clean(r.get("Admission Number")),
            "blood_group": gate("blood_group", _clean(r.get("Blood Group"))),
            "disability_status": gate("disability_status", _clean(r.get("Disability Status"))),
            "academic_year": ay,
        }
        pmeta = _meta({
            "mother_tongue": _clean(r.get("Mother Tongue")),
            "religion": gate("religion", _clean(r.get("Religion"))),
            "transport_required": _clean(r.get("Transport Required")),
            "fee_plan": _clean(r.get("Fee Plan")),
        })
        if pmeta:
            profile["metadata"] = pmeta
        students.append({
            "entity_type": "student",
            "first_name": _clean(r.get("First Name")),
            "last_name": _clean(r.get("Last Name")),
            "_profile": profile,
            "_parent_phone": _clean(r.get("Parent Phone (lookup)")),
        })

    # --- TEACHER ASSIGNMENTS -> teacher_assignments (one row per line) ---
    assignments = []
    for _, r in _rows(assign_df):
        is_ct = (_clean(r.get("Is Class Teacher")) or "").lower() == "yes"
        assignments.append({
            "_teacher_phone": _clean(r.get("Teacher Phone (lookup)")),
            "class": _clean(r.get("Class")),
            "section": _clean(r.get("Section")),
            "subject_code": _clean(r.get("Subject Code")),
            "role": "Class Teacher" if is_ct else "Subject Teacher",
            "academic_year": ay,
            "is_active": True,
        })

    return {
        "teachers": teachers,
        "parents": parents,
        "students": students,
        "teacher_assignments": assignments,
    }
