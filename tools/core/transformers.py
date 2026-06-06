"""core/transformers.py — turns raw spreadsheet rows into database-ready rows,
following the recipe in a client's YAML config. Pure data work: NO database
calls happen here, so the output is plain dicts you can eyeball before anything
is inserted.

Foreign keys (entity_id, parent_id, parent_entity_id) are NOT resolved here —
those are real database UUIDs that only exist after insertion. The loader fills
them in. This module just carries the raw values the loader needs under a
reserved '_links' key."""

from __future__ import annotations
import pandas as pd


def _lower(v):
    return v.lower() if isinstance(v, str) else v

def _to_date(v):
    """Any date text -> 'YYYY-MM-DD' (what a Postgres `date` column wants)."""
    if v is None:
        return None
    return pd.to_datetime(v).date().isoformat()

def _normalize_class(v):
    """'Class 9' / ' 9 ' -> '9'. Tuned for numeric classes; leaves KG/LKG as-is."""
    if not isinstance(v, str):
        return v
    s = v.strip()
    if s.lower().startswith("class"):
        s = s[5:].strip()
    return s

TRANSFORMS = {"lower": _lower, "to_date": _to_date, "normalize_class": _normalize_class}


def _clean(v):
    """Treat blanks/NaN as None so they become real NULLs later."""
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return None
    if isinstance(v, str) and v.strip() == "":
        return None
    return v


def _resolve_field(row, spec):
    if "const" in spec:
        return spec["const"]
    if "combine" in spec:
        parts = [str(_clean(row.get(c))) for c in spec["combine"] if _clean(row.get(c)) is not None]
        return spec.get("sep", ", ").join(parts) if parts else None
    val = _clean(row.get(spec["from"])) if "from" in spec else None
    if val is not None and "transform" in spec:
        val = TRANSFORMS[spec["transform"]](val)
    return val


def _collect_links(row, mapping):
    """Carry the raw values the loader needs to wire up foreign keys post-insert."""
    links = {}
    for target_col, spec in mapping.get("link", {}).items():
        if isinstance(spec, dict) and "lookup_parent_by" in spec:
            links[target_col] = {"lookup_parent_by": _clean(row.get(spec["lookup_parent_by"]))}
        else:
            links[target_col] = {"pair_by_row": True}
    return links


def transform_block(df: pd.DataFrame, mapping: dict) -> list[dict]:
    rows = []
    for _, r in df.iterrows():
        out = {}
        if "entity_type" in mapping:
            out["entity_type"] = mapping["entity_type"]
        for col, spec in mapping.get("fields", {}).items():
            out[col] = _resolve_field(r, spec)
        meta = {k: _clean(r.get(src)) for k, src in mapping.get("metadata", {}).items()}
        meta = {k: v for k, v in meta.items() if v is not None}
        if meta:
            out["metadata"] = meta
        links = _collect_links(r, mapping)
        if links:
            out["_links"] = links
        rows.append(out)
    return rows


def transform_all(workbook: dict, config: dict) -> dict:
    """Run every mapping block -> {block_name: [row dicts]}."""
    return {
        name: transform_block(workbook[m["source_sheet"]], m)
        for name, m in config["mappings"].items()
    }
