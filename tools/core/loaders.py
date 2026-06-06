"""core/loaders.py — turns the transformed rows into a single, ordered SQL
transaction that inserts parents, students, their comms prefs, and academic
profiles, with all foreign keys correctly wired.

Key technique: we pre-generate the entity UUIDs in Python. That way every
foreign key (parent_id, entity_id, parent_entity_id) is a known value before
we write a line of SQL — no fragile chaining of database-generated ids — and
the whole thing is one BEGIN/COMMIT block that rolls back cleanly on any error.

This module only BUILDS the SQL text. Applying it to Supabase is a separate,
deliberate step."""

from __future__ import annotations
import json, uuid


def _lit(v) -> str:
    """Render a Python value as a safe SQL literal."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, dict):
        return "'" + json.dumps(v, ensure_ascii=False).replace("'", "''") + "'::jsonb"
    return "'" + str(v).replace("'", "''") + "'"


def _insert(table: str, row: dict) -> str:
    cols = list(row.keys())
    vals = ", ".join(_lit(row[c]) for c in cols)
    return f"INSERT INTO biz_001.{table} ({', '.join(cols)}) VALUES ({vals});"


def build_insert_sql(transformed: dict, config: dict) -> str:
    parents   = transformed["parents"]
    comms     = transformed["parent_comms"]
    students  = transformed["students"]
    profiles  = transformed["student_profiles"]

    parent_ids  = [str(uuid.uuid4()) for _ in parents]
    student_ids = [str(uuid.uuid4()) for _ in students]
    phone_to_parent = {p["phone"]: pid for p, pid in zip(parents, parent_ids)}

    lines = [
        f"-- Migration for {config['client']['name']} ({config['client']['business_id']})",
        f"-- {len(parents)} parents, {len(students)} students",
        "BEGIN;",
        "",
        "-- 1. Parents (entities)",
    ]
    for p, pid in zip(parents, parent_ids):
        row = {"id": pid, **{k: v for k, v in p.items() if k != "_links"}}
        lines.append(_insert("entities", row))

    lines += ["", "-- 2. Communication preferences (one per parent)"]
    for c, pid in zip(comms, parent_ids):
        row = {"parent_entity_id": pid, **{k: v for k, v in c.items() if k != "_links"}}
        lines.append(_insert("communication_preferences", row))

    lines += ["", "-- 3. Students (entities)"]
    for s, sid in zip(students, student_ids):
        row = {"id": sid, **{k: v for k, v in s.items() if k != "_links"}}
        lines.append(_insert("entities", row))

    lines += ["", "-- 4. Student profiles (linked to student + parent)"]
    for prof, sid in zip(profiles, student_ids):
        parent_phone = prof["_links"]["parent_id"]["lookup_parent_by"]
        if parent_phone not in phone_to_parent:
            raise ValueError(
                f"Student {prof.get('roll_number')} references parent phone "
                f"{parent_phone}, which is not in the parents sheet. Aborting."
            )
        row = {
            "entity_id": sid,
            "parent_id": phone_to_parent[parent_phone],
            **{k: v for k, v in prof.items() if k != "_links"},
        }
        lines.append(_insert("student_profiles", row))

    lines += ["", "COMMIT;"]
    return "\n".join(lines)
