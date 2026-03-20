"""
Load Step 1: Load Labels into PostgreSQL
Uses UPSERT on labels.name (UNIQUE).
"""

import pandas as pd
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import CLEAN_DIR
from load.loader import execute_values_upsert


def run():
    print("═══ Load: Labels ═══")

    path = CLEAN_DIR / "labels.csv"
    if not path.exists():
        print("  ⚠ labels.csv not found; run transforms first.")
        return

    df = pd.read_csv(path)
    rows = []
    for _, r in df.iterrows():
        rows.append({
            "name": r["name"],
            "contact_email": r.get("contact_email"),
        })

    execute_values_upsert(
        table="labels",
        columns=["name", "contact_email"],
        rows=rows,
        conflict_columns=["name"],
        update_columns=["contact_email"],
    )
    print(f"  Upserted {len(rows)} labels")
    print("═══ Labels load complete ═══\n")


if __name__ == "__main__":
    run()
