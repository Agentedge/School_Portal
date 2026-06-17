"""sources/excel.py — reads the v3 people-first collection workbook (.xlsx) into
clean pandas DataFrames (Pass A: Teachers, Parents, Students, Teacher Assignments).

Strict v3 layout — every people tab is shaped identically:
    excel row 1  (idx 0) -> title
    excel row 2  (idx 1) -> instructions
    excel row 3  (idx 2) -> "delete the sample row" warning
    excel row 4  (idx 3) -> HEADER ROW          <- column names
    excel row 5  (idx 4) -> yellow SAMPLE row    <- always skipped, never data
    excel row 6+ (idx 5) -> real data

Sheets are matched by the text AFTER the leading emoji (the joined-emoji titles
corrupt on copy), e.g. '👨‍🏫 Teachers' -> 'teachers'. Everything is read as text
so phone / admission numbers aren't reformatted by pandas. No asterisk-stripping
and no Given/Surname relabelling — v3 headers are plain 'First Name' / 'Last Name'."""

from __future__ import annotations
import pandas as pd

HEADER_IDX = 3   # excel row 4
DATA_IDX = 5     # excel row 6 (idx 4 / excel row 5 is the yellow sample -> skipped)

# canonical key  ->  trailing token to match at the end of a sheet's name
SHEET_TOKENS = {
    "teachers": "Teachers",
    "parents": "Parents",
    "students": "Students",
    "teacher_assignments": "Teacher Assignments",
}


def _read_sheet(path: str, sheet_name: str) -> pd.DataFrame:
    """One v3 tab -> clean all-text DataFrame: header at row 4, data from row 6,
    sample row skipped, blank rows removed, whitespace stripped."""
    raw = pd.read_excel(path, sheet_name=sheet_name, header=None, dtype=str)
    cols = [str(c).strip() if pd.notna(c) else c for c in raw.iloc[HEADER_IDX].tolist()]
    df = raw.iloc[DATA_IDX:].copy()
    df.columns = cols
    df = df.dropna(how="all")
    for c in df.columns:
        df[c] = df[c].apply(lambda v: v.strip() if isinstance(v, str) else v)
    return df.reset_index(drop=True)


def read_workbook(path: str) -> dict:
    """Read the four Pass-A people tabs, keyed by canonical name. Matching is by
    trailing token, so the leading emoji is irrelevant. A tab that isn't present
    is simply absent from the result (the validator reports it)."""
    xl = pd.ExcelFile(path)
    out = {}
    for key, token in SHEET_TOKENS.items():
        match = next((s for s in xl.sheet_names if str(s).endswith(token)), None)
        if match is not None:
            out[key] = _read_sheet(path, match)
    return out
