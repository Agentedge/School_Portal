"""core/loaders.py — turns the transformed v3 people rows into a single, ordered
SQL transaction: teachers, parents (deduped), students + profiles, and teacher
assignments, with every foreign key wired.

Key technique: entity UUIDs are pre-generated in Python, so every FK (parent_id,
teacher_id, entity_id) is a known value before a line of SQL is written — no
fragile chaining of database-generated ids — and the whole thing is one
BEGIN/COMMIT block that rolls back cleanly on any error.

This module only BUILDS the SQL text. Applying it to Supabase is a separate,
deliberate step (no DB connection lives here)."""

from __future__ import annotations
import json, re, uuid

MAX_HANDLE = 10   # login_id base is capped to ~10 chars (before any suffix)


def _lit(v) -> str:
    """Render a Python value as a safe SQL literal."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, dict):
        return "'" + json.dumps(v, ensure_ascii=False).replace("'", "''") + "'::jsonb"
    return "'" + str(v).replace("'", "''") + "'"


def _insert(schema: str, table: str, row: dict) -> str:
    cols = list(row.keys())
    vals = ", ".join(_lit(row[c]) for c in cols)
    return f"INSERT INTO {schema}.{table} ({', '.join(cols)}) VALUES ({vals});"


# ---- login_id handles ----------------------------------------------------

def _slug(v) -> str:
    """Lowercase a value and drop every non-alphanumeric character."""
    return re.sub(r"[^a-z0-9]", "", str(v).lower()) if v is not None else ""


def _base_handle(first_name, last_name) -> str:
    """Name-based handle base: first 2 letters of last name + full first name,
    lowercased, alphanumeric only, capped at MAX_HANDLE chars.
    'Avadhanula' + 'Bhargav' -> 'avbhargav'."""
    return (_slug(last_name)[:2] + _slug(first_name))[:MAX_HANDLE]


def _assign_login_ids(transformed: dict) -> list[str]:
    """Give every entity a globally-unique login handle on row['login_id'].
    Order: teachers -> parents -> students (teachers get first pick), one shared
    used-set. The first holder of a base keeps it bare; later collisions get the
    smallest free integer suffix (akhil, akhil2, akhil3). The UUID 'id' stays the
    internal key. Returns human-readable notes for the validation report."""
    used: set = set()
    counts: dict = {}
    notes: list = []
    for block in ("teachers", "parents", "students"):
        for row in transformed.get(block, []):
            base = _base_handle(row.get("first_name"), row.get("last_name"))
            n = counts.get(base, 0) + 1
            handle = base if n == 1 else f"{base}{n}"
            while handle in used:          # guard against a literal base clash
                n += 1
                handle = f"{base}{n}"
            counts[base] = n
            used.add(handle)
            row["login_id"] = handle
            if n > 1:
                notes.append(f"{block[:-1]} handle '{base}' taken -> '{handle}' "
                             f"({row.get('first_name')} {row.get('last_name')})")
    return notes


# ---- SQL builder ---------------------------------------------------------

def _entity_row(rid: str, e: dict) -> dict:
    """Entity insert dict: the pre-minted id + every non-reserved field."""
    return {"id": rid, **{k: v for k, v in e.items() if not k.startswith("_")}}


def build_insert_sql(transformed: dict, config: dict) -> str:
    schema = config["client"]["business_id"]
    transformed["_handle_warnings"] = _assign_login_ids(transformed)

    teachers = transformed["teachers"]
    parents = transformed["parents"]
    students = transformed["students"]
    assignments = transformed["teacher_assignments"]

    teacher_ids = [str(uuid.uuid4()) for _ in teachers]
    parent_ids = [str(uuid.uuid4()) for _ in parents]
    student_ids = [str(uuid.uuid4()) for _ in students]

    phone_to_parent = {p["_phone"]: pid for p, pid in zip(parents, parent_ids) if p.get("_phone")}
    phone_to_teacher = {t["_phone"]: tid for t, tid in zip(teachers, teacher_ids) if t.get("_phone")}

    lines = [
        f"-- Pass A people migration: {config['client']['name']} ({schema})",
        f"-- {len(teachers)} teachers, {len(parents)} parents, {len(students)} students, "
        f"{len(assignments)} teacher_assignments",
        f"-- dpa_signed={config.get('dpa_signed', False)} "
        f"(gated columns written NULL while false)",
        "BEGIN;",
        "",
        "-- 1. Teachers (entities)",
    ]
    for t, tid in zip(teachers, teacher_ids):
        lines.append(_insert(schema, "entities", _entity_row(tid, t)))

    lines += ["", "-- 2. Parents (entities, deduped by Primary Phone)"]
    for p, pid in zip(parents, parent_ids):
        lines.append(_insert(schema, "entities", _entity_row(pid, p)))

    lines += ["", "-- 3. Students (entities)"]
    for s, sid in zip(students, student_ids):
        lines.append(_insert(schema, "entities", _entity_row(sid, s)))

    lines += ["", "-- 4. Student profiles (entity_id + parent_id; orphan -> NULL parent)"]
    for s, sid in zip(students, student_ids):
        parent_id = phone_to_parent.get(s.get("_parent_phone"))   # None -> NULL (orphan)
        row = {"entity_id": sid, "parent_id": parent_id, **s["_profile"]}
        lines.append(_insert(schema, "student_profiles", row))

    lines += ["", "-- 5. Teacher assignments (class/section/role; auth_user_id set later)"]
    for a in assignments:
        tid = phone_to_teacher.get(a.get("_teacher_phone"))
        if tid is None:
            continue   # unknown teacher phone — validator already warned
        row = {
            "teacher_id": tid,
            "auth_user_id": None,
            "class": a["class"],
            "section": a["section"],
            "role": a["role"],
            "academic_year": a["academic_year"],
            "is_active": a["is_active"],
        }
        lines.append(_insert(schema, "teacher_assignments", row))

    lines += ["", "COMMIT;"]
    return "\n".join(lines)
