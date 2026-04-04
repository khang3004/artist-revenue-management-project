"""
Apply V8__patch_missing_schema.sql to the Neon database.

Handles multi-statement SQL including DO $$ ... $$ blocks by splitting
on semicolons that appear outside of dollar-quote blocks.

Usage:
    uv run db/migrations/apply_patch.py
"""

import re
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../.."))


def split_sql_statements(sql: str) -> list[str]:
    """Split SQL text into individual statements, respecting $$ quote blocks."""
    statements = []
    current = []
    in_dollar_quote = False
    dollar_tag = ""

    for line in sql.split("\n"):
        stripped = line.strip()

        # Toggle dollar-quote state
        matches = re.findall(r"\$[^$]*\$", line)
        for m in matches:
            if not in_dollar_quote:
                in_dollar_quote = True
                dollar_tag = m
            elif m == dollar_tag:
                in_dollar_quote = False
                dollar_tag = ""

        current.append(line)

        # Flush when we hit a semicolon outside a dollar-quote block
        if not in_dollar_quote and stripped.endswith(";"):
            stmt = "\n".join(current).strip()
            # Strip leading comment lines to find the first real SQL line
            real_lines = [l for l in stmt.splitlines() if l.strip() and not l.strip().startswith("--")]
            if real_lines:
                statements.append(stmt)
            current = []

    # Trailing content with no final semicolon
    remaining = "\n".join(current).strip()
    real_lines = [l for l in remaining.splitlines() if l.strip() and not l.strip().startswith("--")]
    if real_lines:
        statements.append(remaining)

    return statements


def main():
    sql_path = os.path.join(os.path.dirname(__file__), "V8__patch_missing_schema.sql")
    with open(sql_path, "r", encoding="utf-8") as f:
        sql = f.read()

    statements = split_sql_statements(sql)
    print(f"Found {len(statements)} statements to execute.\n")

    from etl.load.loader import get_engine
    from sqlalchemy import text
    engine = get_engine()

    ok = 0
    errors = []
    # Use autocommit so each DDL statement is its own transaction.
    # This prevents one failure from aborting subsequent statements.
    with engine.connect() as conn:
        conn.execution_options(isolation_level="AUTOCOMMIT")
        for stmt in statements:
            preview = stmt.replace("\n", " ")[:70]
            try:
                conn.execute(text(stmt))
                print(f"  OK  {preview}")
                ok += 1
            except Exception as e:
                short_err = str(e).split("\n")[0]
                print(f"  ERR {preview}")
                print(f"      → {short_err}")
                errors.append((preview, short_err))

    print(f"\n{'─'*60}")
    print(f"  {ok}/{len(statements)} statements succeeded")
    if errors:
        print(f"  {len(errors)} error(s):")
        for preview, err in errors:
            print(f"    • {preview[:60]} — {err[:80]}")
        sys.exit(1)
    else:
        print("  Migration V8 applied successfully!")


if __name__ == "__main__":
    main()
