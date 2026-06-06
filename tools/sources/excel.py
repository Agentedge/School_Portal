"""sources/excel.py — reads a client's onboarding workbook (.xlsx) into clean
pandas DataFrames. Finds the header row dynamically (template ships with
title/instruction/warning lines above it that a client may or may not delete),
and reads everything as text so phone/admission numbers aren't corrupted."""

from __future__ import annotations
import pandas as pd

SHEET_KEYS = {
    "🏫 School Info": "school_info",
    "📅 Academic Calendar": "academic_calendar",
    "👨‍🏫 Teachers": "teachers",
    "📚 Subjects (Class 9)": "subjects",
    "🔗 Teacher Assignments": "teacher_assignments",
    "👨‍👩‍👧 Parents": "parents",
    "👦 Students": "students",
    "💰 Fee Structure": "fee_structure",
    "🚌 Transport Routes": "transport_routes",
    "🚏 Transport Stops": "transport_stops",
    "🎒 Student Transport": "student_transport",
    "💳 Fee Payments": "fee_payments",
    "📋 Admissions": "admissions",
}


def _find_header_row(raw: pd.DataFrame, min_filled: int = 2) -> int:
    """First row with >= min_filled non-empty cells. Title/instruction/warning
    rows only fill column 0, so they get skipped."""
    for i in range(len(raw)):
        if raw.iloc[i].notna().sum() >= min_filled:
            return i
    raise ValueError("No header row found (no row had 2+ filled cells).")


def read_sheet(path: str, sheet_name: str) -> pd.DataFrame:
    """One sheet -> clean all-text DataFrame: header located, preamble dropped,
    blank rows removed, whitespace stripped."""
    raw = pd.read_excel(path, sheet_name=sheet_name, header=None, dtype=str)
    h = _find_header_row(raw)
    cols = raw.iloc[h].tolist()
    df = raw.iloc[h + 1:].copy()
    df.columns = cols
    df = df.dropna(how="all")
    for c in df.columns:
        df[c] = df[c].str.strip()
    return df.reset_index(drop=True)


def read_workbook(path: str) -> dict[str, pd.DataFrame]:
    """Every known sheet -> dict keyed by clean name. Instructions/unknown
    sheets ignored."""
    xl = pd.ExcelFile(path)
    out = {}
    for sheet in xl.sheet_names:
        key = SHEET_KEYS.get(sheet)
        if key is None:
            continue
        out[key] = read_sheet(path, sheet)
    return out
