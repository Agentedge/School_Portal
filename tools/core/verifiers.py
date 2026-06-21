"""core/verifiers.py — generates post-load verification SQL for the Pass-A people
load: confirms the teacher / parent / student entities, profiles, and assignments
landed, and shows each student's parent link (orphans surface as NULL parent).

No database connection — it builds SQL, consistent with the rest of the toolbox.
Expected counts are written in as comments so you can compare at a glance."""

from __future__ import annotations


def _arr(values) -> str:
    inner = ", ".join("'" + str(v).replace("'", "''") + "'" for v in values)
    return f"ARRAY[{inner}]"


def build_verification_sql(transformed: dict, config: dict) -> str:
    schema = config["client"]["business_id"]
    teacher_phones = [t["_phone"] for t in transformed["teachers"] if t.get("_phone")]
    parent_phones = [p["_phone"] for p in transformed["parents"] if p.get("_phone")]
    admissions = [s["_profile"].get("admission_number") for s in transformed["students"]
                  if s["_profile"].get("admission_number")]
    n_t, n_p = len(transformed["teachers"]), len(transformed["parents"])
    n_s, n_a = len(transformed["students"]), len(transformed["teacher_assignments"])

    lines = [
        f"-- Verification for {config['client']['name']} ({schema}) — Pass A people",
        f"-- EXPECT: teachers={n_t}, parents={n_p}, students={n_s}, assignments={n_a}",
        "",
        "-- 1. Counts: did the rows we built actually land?",
        "SELECT",
        f"  (SELECT count(*) FROM {schema}.entities",
        f"     WHERE entity_type='teacher' AND phone = ANY({_arr(teacher_phones)})) AS teachers_found,",
        f"  (SELECT count(*) FROM {schema}.entities",
        f"     WHERE entity_type='parent'  AND phone = ANY({_arr(parent_phones)})) AS parents_found,",
        f"  (SELECT count(*) FROM {schema}.student_profiles",
        f"     WHERE admission_number = ANY({_arr(admissions)})) AS profiles_found,",
        f"  (SELECT count(*) FROM {schema}.teacher_assignments ta",
        f"     JOIN {schema}.entities e ON e.id = ta.teacher_id",
        f"     WHERE e.phone = ANY({_arr(teacher_phones)})) AS assignments_found;",
        "",
        f"-- 2. Roster + parent link (orphan -> parent_login/phone NULL). EXPECT {n_s} rows.",
        "SELECT se.login_id, se.first_name || ' ' || se.last_name AS student,",
        "       sp.roll_number, sp.class, sp.section,",
        "       pe.login_id AS parent_login, pe.phone AS parent_phone",
        f"FROM {schema}.student_profiles sp",
        f"JOIN {schema}.entities se ON se.id = sp.entity_id",
        f"LEFT JOIN {schema}.entities pe ON pe.id = sp.parent_id",
        f"WHERE sp.admission_number = ANY({_arr(admissions)})",
        "ORDER BY sp.roll_number;",
    ]
    return "\n".join(lines)
