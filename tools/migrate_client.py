"""tools/migrate_client.py — the one command that runs the whole migration
pipeline for a client, in generate mode (no database connection).

    python tools/migrate_client.py tools/configs/stephens.yaml

Steps:
  1. read the client's workbook
  2. validate it — STOP here if there are any errors (nothing is generated)
  3. transform the rows
  4. write the migration SQL    -> tools/output/<name>_migration.sql
  5. write the verification SQL -> tools/output/<name>_verify.sql

Applying the SQL to Supabase remains a separate, manual step in the editor."""

from __future__ import annotations
import sys, os, pathlib, yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sources.excel import read_workbook
from core.validators import validate, format_issues, has_errors
from core.transformers import transform_all
from core.loaders import build_insert_sql
from core.verifiers import build_verification_sql


def main(config_path: str) -> int:
    cfg = yaml.safe_load(open(config_path))
    name = pathlib.Path(config_path).stem
    print(f"== Migration build for {cfg['client']['name']} ({cfg['client']['business_id']}) ==\n")

    wb = read_workbook(cfg["client"]["source_file"])

    issues = validate(wb, cfg)
    print(format_issues(issues))
    if has_errors(issues):
        print("\nABORTED: fix the errors above before any SQL is generated.")
        return 1

    data = transform_all(wb, cfg)
    out_dir = pathlib.Path(os.path.dirname(os.path.abspath(__file__))) / "output"
    out_dir.mkdir(exist_ok=True)
    mig = out_dir / f"{name}_migration.sql"
    ver = out_dir / f"{name}_verify.sql"
    mig.write_text(build_insert_sql(data, cfg))
    ver.write_text(build_verification_sql(data, cfg))

    print(f"\nValidation passed. {len(data['parents'])} parents, {len(data['students'])} students.")
    print(f"  migration SQL  -> {mig}")
    print(f"  verification   -> {ver}")
    print("\nNext: open each in the Supabase SQL editor and run them (migration first).")
    return 0


if __name__ == "__main__":
    config = sys.argv[1] if len(sys.argv) > 1 else "tools/configs/stephens.yaml"
    raise SystemExit(main(config))
