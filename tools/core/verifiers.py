"""core/verifiers.py — generates post-load verification SQL: confirms the rows
that were supposed to land actually landed, and that each student is linked to
the right parent. Run the output in the Supabase editor after a migration, the
same way you run the migration SQL.

No database connection here — it builds SQL, consistent with the rest of the
toolbox. Expected counts are written into the output as comments so you can
compare at a glance."""

from __future__ import annotations


def _arr(values) -> str:
    inner = ", ".join("'" + str(v).replace("'", "''") + "'" for v in values)
    return f"ARRAY[{inner}]"


def build_verification_sql(transformed: dict, config: dict) -> str:
    schema = config["client"]["business_id"]
    parent_phones = [p["phone"] for p in transformed["parents"] if p.get("phone")]
    admissions = [pr["admission_number"] for pr in transformed["student_profiles"]
                  if pr.get("admission_number")]
    n_parents = len(transformed["parents"])
    n_students = len(transformed["student_profiles"])

    lines = [
        f"-- Verification for {config['client']['name']} ({schema})",
        f"-- EXPECT: parents_found = {n_parents}, profiles_found = {n_students}, comms_found = {n_parents}",
        "",
        "-- 1. Counts: do the rows we loaded actually exist?",
        "SELECT",
        f"  (SELECT count(*) FROM {schema}.entities",
        f"     WHERE entity_type = 'parent' AND phone = ANY({_arr(parent_phones)})) AS parents_found,",
        f"  (SELECT count(*) FROM {schema}.student_profiles",
        f"     WHERE admission_number = ANY({_arr(admissions)})) AS profiles_found,",
        f"  (SELECT count(*) FROM {schema}.communication_preferences cp",
        f"     JOIN {schema}.entities e ON e.id = cp.parent_entity_id",
        f"     WHERE e.phone = ANY({_arr(parent_phones)})) AS comms_found;",
        "",
        f"-- 2. Linkage: each student -> their parent. EXPECT {n_students} rows, correct parent on each.",
        "SELECT",
        "  se.first_name || ' ' || se.last_name AS student,",
        "  sp.roll_number, sp.class, sp.admission_number,",
        "  pe.first_name AS parent, pe.phone AS parent_phone,",
        "  cp.preferred_language",
        f"FROM {schema}.student_profiles sp",
        f"JOIN {schema}.entities se ON se.id = sp.entity_id",
        f"JOIN {schema}.entities pe ON pe.id = sp.parent_id",
        f"JOIN {schema}.communication_preferences cp ON cp.parent_entity_id = sp.parent_id",
        f"WHERE sp.admission_number = ANY({_arr(admissions)})",
        "ORDER BY sp.roll_number;",
    ]
    return "\n".join(lines)
