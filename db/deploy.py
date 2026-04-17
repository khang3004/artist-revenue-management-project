import os
import glob
import time
import json
from dataclasses import dataclass, asdict
from sqlalchemy import create_engine, text

# =========================
# CONFIG
# =========================
try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

DB_URL = os.getenv("DATABASE_URL")

if not DB_URL:
    raise Exception("Missing DATABASE_URL env var")

engine = create_engine(DB_URL, isolation_level="AUTOCOMMIT")


# =========================
# RESULT MODEL
# =========================

@dataclass
class StepResult:
    file: str
    ok: int
    fail: int
    errors: list
    duration_ms: int


# =========================
# SQL PARSER (FIXED)
# =========================

def split_sql(sql: str):
    """
    Safe SQL splitter:
    - ignores comment-only blocks
    - supports $$ functions
    - avoids empty execution
    """
    statements = []
    buffer = []
    in_dollar = False

    lines = sql.splitlines()

    for line in lines:
        stripped = line.strip()

        # toggle $$ block
        if "$$" in line:
            in_dollar = not in_dollar

        buffer.append(line)

        # end statement
        if not in_dollar and stripped.endswith(";"):
            stmt = "\n".join(buffer).strip()

            # filter empty/comment-only
            real_lines = [
                l for l in stmt.splitlines()
                if l.strip() and not l.strip().startswith("--")
            ]

            if real_lines:
                statements.append(stmt)

            buffer = []

    return statements


# =========================
# EXECUTOR
# =========================

def run_file(path: str, continue_on_error=True) -> StepResult:
    start = time.time()

    ok = 0
    fail = 0
    errors = []

    print(f"\n🚀 Running: {os.path.basename(path)}")

    try:
        with open(path, "r", encoding="utf-8") as f:
            sql = f.read()
    except Exception as e:
        return StepResult(path, 0, 1, [str(e)], 0)

    statements = split_sql(sql)

    with engine.connect() as conn:
        for stmt in statements:
            try:
                conn.execute(text(stmt))
                ok += 1
                print("   ✅ OK")
            except Exception as e:
                fail += 1
                err = str(e).split("\n")[0]
                errors.append(err)

                print("   ❌ FAIL")
                print("      →", err)

                if not continue_on_error:
                    break

    duration = int((time.time() - start) * 1000)

    return StepResult(
        file=path,
        ok=ok,
        fail=fail,
        errors=errors,
        duration_ms=duration
    )


# =========================
# SIMPLE ORDERING LAYER
# =========================

def get_execution_plan(folder):
    """
    Minimal safe ordering:
    migrations → procedures → seeds
    """
    return sorted(glob.glob(folder))


# =========================
# RUNNER
# =========================

def run_group(name, pattern, report):
    print("\n" + "=" * 60)
    print(f"📦 {name}")
    print("=" * 60)

    files = get_execution_plan(pattern)

    for f in files:
        result = run_file(f)
        report.append(result)


# =========================
# MAIN
# =========================

if __name__ == "__main__":

    report = []

    run_group("MIGRATIONS", "db/migrations/*.sql", report)
    run_group("PROCEDURES", "db/procedures/*.sql", report)
    run_group("SEEDS", "db/seeds/*.sql", report)

    # =========================
    # SUMMARY
    # =========================

    summary = {
        "total_files": len(report),
        "total_ok": sum(r.ok for r in report),
        "total_fail": sum(r.fail for r in report),
        "files": [asdict(r) for r in report]
    }

    print("\n" + "=" * 60)
    print("📊 DEPLOY SUMMARY")
    print("=" * 60)
    print(json.dumps(summary, indent=2))

    # save report
    with open("deploy_report.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    print("\n📁 Report saved: deploy_report.json")