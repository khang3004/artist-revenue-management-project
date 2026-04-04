"""
Deploy all stored procedures from db/procedures/ to Neon.

Reads every .sql file in db/procedures/ (skipping .gitkeep) and executes
each CREATE OR REPLACE FUNCTION / PROCEDURE statement against the database.

Usage:
    uv run db/migrations/deploy_procedures.py
"""

import re
import sys
import os
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../.."))


def split_sql_statements(sql: str) -> list[str]:
    """Split SQL text into individual statements, respecting $$ quote blocks."""
    statements = []
    current = []
    in_dollar_quote = False
    dollar_tag = ""

    for line in sql.split("\n"):
        stripped = line.strip()

        matches = re.findall(r"\$[^$]*\$", line)
        for m in matches:
            if not in_dollar_quote:
                in_dollar_quote = True
                dollar_tag = m
            elif m == dollar_tag:
                in_dollar_quote = False
                dollar_tag = ""

        current.append(line)

        if not in_dollar_quote and stripped.endswith(";"):
            stmt = "\n".join(current).strip()
            real_lines = [l for l in stmt.splitlines() if l.strip() and not l.strip().startswith("--")]
            if real_lines:
                statements.append(stmt)
            current = []

    remaining = "\n".join(current).strip()
    real_lines = [l for l in remaining.splitlines() if l.strip() and not l.strip().startswith("--")]
    if real_lines:
        statements.append(remaining)

    return statements


def main():
    procs_dir = Path(__file__).parent.parent / "procedures"
    sql_files = sorted(f for f in procs_dir.glob("*.sql") if f.name != ".gitkeep")

    print(f"Found {len(sql_files)} procedure files.\n")

    from etl.load.loader import get_engine
    from sqlalchemy import text
    engine = get_engine()

    total_ok = 0
    total_err = 0

    with engine.connect() as conn:
        conn.execution_options(isolation_level="AUTOCOMMIT")
        for sql_file in sql_files:
            print(f"── {sql_file.name}")
            sql = sql_file.read_text(encoding="utf-8")
            statements = split_sql_statements(sql)
            for stmt in statements:
                preview = stmt.replace("\n", " ")[:70]
                try:
                    conn.execute(text(stmt))
                    print(f"   OK  {preview}")
                    total_ok += 1
                except Exception as e:
                    short_err = str(e).split("\n")[0]
                    # If return type mismatch, drop the function and retry
                    if "cannot change return type" in short_err:
                        fn_match = re.search(
                            r"FUNCTION\s+(\w+)\s*\(", stmt, re.IGNORECASE
                        )
                        if fn_match:
                            fn_name = fn_match.group(1)
                            drop_sql = f"DROP FUNCTION IF EXISTS {fn_name} CASCADE;"
                            try:
                                conn.execute(text(drop_sql))
                                conn.execute(text(stmt))
                                print(f"   OK  (dropped+recreated) {preview}")
                                total_ok += 1
                                continue
                            except Exception as e2:
                                short_err = str(e2).split("\n")[0]
                    print(f"   ERR {preview}")
                    print(f"       → {short_err}")
                    total_err += 1

    print(f"\n{'─'*60}")
    print(f"  {total_ok} statements succeeded, {total_err} failed")
    if total_err:
        sys.exit(1)
    else:
        print("  All procedures deployed successfully!")


if __name__ == "__main__":
    main()
