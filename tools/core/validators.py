"""core/validators.py — pre-flight data-quality checks that run on the RAW
workbook, before anything is transformed or inserted. Returns a list of issues;
the migration should abort if any are ERRORs.

Runs on raw sheets (not transformed rows) so it reports bad data cleanly instead
of letting the transformer crash on, say, an unparseable date.

Most checks are derived from the config — which columns are dates, which is the
join key, where the parent link points. A small built-in set knows that
admission/roll numbers must be unique within a sheet."""

from __future__ import annotations
import pandas as pd

_UNIQUE_TARGETS = {"admission_number", "roll_number"}


def _src(mapping, target_field):
    spec = mapping.get("fields", {}).get(target_field)
    return spec["from"] if isinstance(spec, dict) and "from" in spec else None


def _norm(series):
    return series.fillna("").astype(str).str.strip()


def validate(workbook: dict, config: dict) -> list[dict]:
    issues = []
    def err(block, msg): issues.append({"level": "ERROR", "block": block, "msg": msg})

    mappings = config["mappings"]
    parent_block = next((m for m in mappings.values()
                         if m.get("join_key") and m.get("entity_type") == "parent"), None)

    for name, m in mappings.items():
        sheet = m["source_sheet"]
        if sheet not in workbook:
            err(name, f"source sheet '{sheet}' not found")
            continue
        df = workbook[sheet]

        referenced = set()
        for spec in m.get("fields", {}).values():
            if isinstance(spec, dict):
                if "from" in spec: referenced.add(spec["from"])
                if "combine" in spec: referenced.update(spec["combine"])
        referenced.update(m.get("metadata", {}).values())
        for col in referenced:
            if col not in df.columns:
                err(name, f"column '{col}' is missing from sheet '{sheet}'")

        if "entity_type" in m:
            fn = _src(m, "first_name")
            if fn and fn in df.columns:
                for i in df.index[_norm(df[fn]) == ""]:
                    err(name, f"row {i}: name source '{fn}' is blank")

        jk = m.get("join_key")
        if jk:
            col = _src(m, jk)
            if col and col in df.columns:
                vals = _norm(df[col])
                for i in df.index[vals == ""]:
                    err(name, f"row {i}: join key '{col}' is blank")
                nb = vals[vals != ""]
                for v in sorted(set(nb[nb.duplicated(keep=False)])):
                    err(name, f"join key '{col}' value '{v}' is duplicated")

        for tgt in _UNIQUE_TARGETS:
            col = _src(m, tgt)
            if col and col in df.columns:
                nb = _norm(df[col])
                nb = nb[nb != ""]
                for v in sorted(set(nb[nb.duplicated(keep=False)])):
                    err(name, f"{tgt} '{col}' value '{v}' is duplicated")

        for tgt, spec in m.get("fields", {}).items():
            if isinstance(spec, dict) and spec.get("transform") == "to_date":
                col = spec.get("from")
                if col and col in df.columns:
                    for i, v in df[col].items():
                        s = "" if v is None else str(v).strip()
                        if not s:
                            continue
                        try:
                            pd.to_datetime(s)
                        except Exception:
                            err(name, f"row {i}: '{col}' value '{v}' is not a valid date")

        for spec in m.get("link", {}).values():
            if isinstance(spec, dict) and "lookup_parent_by" in spec and parent_block:
                lookup_col = spec["lookup_parent_by"]
                pj = _src(parent_block, parent_block["join_key"])
                parents_have = set(_norm(workbook[parent_block["source_sheet"]][pj]))
                if lookup_col in df.columns:
                    for i, v in df[lookup_col].items():
                        s = "" if v is None else str(v).strip()
                        if s and s not in parents_have:
                            err(name, f"row {i}: parent phone '{s}' matches no parent in the sheet")

    return issues


def format_issues(issues: list[dict]) -> str:
    if not issues:
        return "No issues found — data is clean."
    out = [f"{len(issues)} issue(s) found:"]
    for it in issues:
        out.append(f"  [{it['level']}] {it['block']}: {it['msg']}")
    return "\n".join(out)


def has_errors(issues: list[dict]) -> bool:
    return any(it["level"] == "ERROR" for it in issues)
