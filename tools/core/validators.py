"""core/validators.py — SOFT-FAIL data-quality checks over the RAW v3 workbook.

Collects ALL issues and returns them; it never raises and never aborts the run.
The pipeline generates SQL regardless — issues are printed together at the end so
a human can decide. Checks: missing required fields, orphan students (a Parent
Phone with no matching parent), duplicate parent phones (collapsed on load), and
class-teacher disagreement between the Teachers tab and the Assignments tab."""

from __future__ import annotations
import re
import pandas as pd

REQUIRED = {
    "teachers": ["First Name", "Last Name", "Phone"],
    "parents": ["Primary Contact Name", "Primary Phone"],
    "students": ["Roll No", "First Name", "Last Name", "Class", "Section", "Parent Phone (lookup)"],
    "teacher_assignments": ["Teacher Phone (lookup)", "Class", "Section"],
}


def _blank(v) -> bool:
    return v is None or (isinstance(v, float) and pd.isna(v)) or (isinstance(v, str) and v.strip() == "")


def _val(v):
    return None if (v is None or (isinstance(v, float) and pd.isna(v))) else str(v).strip() or None


def _parse_class_section(s):
    """'9A' -> ('9', 'A'); '10B' -> ('10', 'B'). Best-effort, never raises."""
    s = (_val(s) or "")
    m = re.match(r"(\d+)\s*([A-Za-z]?)", s)
    return (m.group(1), m.group(2).upper()) if m else (s, "")


def validate(workbook: dict, config: dict) -> list[dict]:
    issues = []
    def warn(block, msg): issues.append({"level": "WARN", "block": block, "msg": msg})

    # 1. required fields present + non-blank
    for key, cols in REQUIRED.items():
        df = workbook.get(key)
        if df is None:
            warn(key, f"tab '{key}' not found in workbook")
            continue
        for col in cols:
            if col not in df.columns:
                warn(key, f"required column '{col}' missing from the tab")
                continue
            for i, v in df[col].items():
                if _blank(v):
                    warn(key, f"row {i}: required '{col}' is blank")

    parents_df = workbook.get("parents")
    students_df = workbook.get("students")
    teachers_df = workbook.get("teachers")
    assign_df = workbook.get("teacher_assignments")

    parent_phones = set()
    if parents_df is not None and "Primary Phone" in parents_df.columns:
        parent_phones = {_val(v) for v in parents_df["Primary Phone"] if _val(v)}

    # 2. orphan students (parent phone with no Parents row)
    if students_df is not None and "Parent Phone (lookup)" in students_df.columns:
        for i, v in students_df["Parent Phone (lookup)"].items():
            ph = _val(v)
            if ph and ph not in parent_phones:
                fn = _val(students_df.at[i, "First Name"]) if "First Name" in students_df.columns else ""
                ln = _val(students_df.at[i, "Last Name"]) if "Last Name" in students_df.columns else ""
                warn("students", f"row {i}: orphan — parent phone '{ph}' has no Parents row "
                                 f"({fn or ''} {ln or ''}); parent_id will be NULL")

    # 3. duplicate parent phones (collapsed to one entity on load)
    if parents_df is not None and "Primary Phone" in parents_df.columns:
        seen = {}
        for i, v in parents_df["Primary Phone"].items():
            ph = _val(v)
            if ph:
                seen.setdefault(ph, []).append(i)
        for ph, rows in seen.items():
            if len(rows) > 1:
                warn("parents", f"duplicate Primary Phone '{ph}' on rows {rows} "
                                f"— collapsed to one parent entity")

    # 4. class-teacher cross-check (authoritative = Assignments 'Is Class Teacher=Yes')
    if teachers_df is not None and assign_df is not None:
        ct_assign = set()   # (phone, class, section) flagged class teacher in Assignments
        for _, r in assign_df.iterrows():
            if (_val(r.get("Is Class Teacher")) or "").lower() == "yes":
                ct_assign.add((_val(r.get("Teacher Phone (lookup)")),
                               _val(r.get("Class")), _val(r.get("Section"))))
        declared = {}      # teacher phone -> Class Teacher Of (parsed)
        for i, r in teachers_df.iterrows():
            ph = _val(r.get("Phone"))
            cto = _val(r.get("Class Teacher Of (e.g. 9A)"))
            declared[ph] = _parse_class_section(cto) if cto else None
            if cto:
                cls, sec = _parse_class_section(cto)
                if (ph, cls, sec) not in ct_assign:
                    warn("teachers", f"row {i}: 'Class Teacher Of {cto}' has no matching "
                                     f"'Is Class Teacher=Yes' assignment row")
        for ph, cls, sec in ct_assign:
            if declared.get(ph) != (cls, sec):
                warn("teacher_assignments", f"teacher {ph} flagged class teacher for {cls}{sec}, "
                     f"but Teachers tab 'Class Teacher Of' = "
                     f"{(''.join(declared[ph]) if declared.get(ph) else 'blank')}")

    return issues


def format_issues(issues: list[dict]) -> str:
    if not issues:
        return "No issues — all rows clean."
    out = [f"{len(issues)} issue(s) (soft — generation continues):"]
    for it in issues:
        out.append(f"  [{it['level']}] {it['block']}: {it['msg']}")
    return "\n".join(out)


def has_errors(issues: list[dict]) -> bool:
    """Soft-fail mode: there are no hard ERRORs, so this is always False. Kept for
    API compatibility with the orchestrator."""
    return any(it["level"] == "ERROR" for it in issues)
