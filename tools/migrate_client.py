"""tools/migrate_client.py — one command that runs the whole Pass-A people
migration for a client, generate-only (NO database connection).

    python tools/migrate_client.py tools/configs/stephens.yaml

Steps:
  1. read the v3 people workbook (Teachers / Parents / Students / Assignments)
  2. validate it — SOFT-FAIL: collect every issue, never abort
  3. transform the rows
  4. write the migration SQL    -> tools/output/<name>_migration.sql
  5. write the verification SQL -> tools/output/<name>_verify.sql
  6. print the validation report, counts, and the full login_id handle list

Applying the SQL to Supabase remains a separate, manual step in the editor."""

from __future__ import annotations
import sys, os, pathlib, yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sources.excel import read_workbook
from core.validators import validate, format_issues
from core.transformers import transform_all
from core.loaders import build_insert_sql
from core.verifiers import build_verification_sql


def main(config_path: str) -> int:
    cfg = yaml.safe_load(open(config_path))
    name = pathlib.Path(config_path).stem
    print(f"== Pass A people migration: {cfg['client']['name']} ({cfg['client']['business_id']}) ==")
    print(f"   source     : {cfg['client']['source_file']}")
    print(f"   dpa_signed : {cfg.get('dpa_signed', False)}  "
          f"(gated: {', '.join(cfg.get('dpa_gated_columns', [])) or 'none'})\n")

    wb = read_workbook(cfg["client"]["source_file"])
    issues = validate(wb, cfg)                 # soft — never aborts
    data = transform_all(wb, cfg)

    out_dir = pathlib.Path(os.path.dirname(os.path.abspath(__file__))) / "output"
    out_dir.mkdir(exist_ok=True)
    mig = out_dir / f"{name}_migration.sql"
    ver = out_dir / f"{name}_verify.sql"
    mig.write_text(build_insert_sql(data, cfg))     # also assigns login_ids
    ver.write_text(build_verification_sql(data, cfg))

    print("---- validation (soft-fail) ----")
    print(format_issues(issues))
    handle_notes = data.get("_handle_warnings", [])
    if handle_notes:
        print("\n---- handle collisions resolved ----")
        for n in handle_notes:
            print(f"  {n}")

    print("\n---- counts ----")
    print(f"  teacher entities         : {len(data['teachers'])}")
    print(f"  parent entities (deduped): {len(data['parents'])}")
    print(f"  student entities         : {len(data['students'])}")
    print(f"  teacher_assignments rows : {data.get('_assignment_rows', len(data['teacher_assignments']))} (deduped)")

    print("\n---- login_id handles (assign order: teachers -> parents -> students) ----")
    for block in ("teachers", "parents", "students"):
        for e in data[block]:
            label = block[:-1]
            name_str = f"{e.get('first_name') or ''} {e.get('last_name') or ''}".strip()
            print(f"  {label:8}  {str(e.get('login_id')):14}  {name_str}")

    print(f"\n  migration SQL  -> {mig}")
    print(f"  verification   -> {ver}")
    print("\nGenerate-only: no database connection was opened. Review the SQL before applying.")
    return 0


if __name__ == "__main__":
    config = sys.argv[1] if len(sys.argv) > 1 else "tools/configs/stephens.yaml"
    raise SystemExit(main(config))
