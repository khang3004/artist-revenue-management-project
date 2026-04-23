"""
Load Step 4: Load Events, Venues, Managers, and Event Performers
"""

import pandas as pd
from sqlalchemy import text
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import CLEAN_DIR
from load.loader import get_engine, execute_sql, execute_values_upsert


def _get_map(table: str, name_col: str, id_col: str) -> dict:
    engine = get_engine()
    with engine.connect() as conn:
        rows = conn.execute(
            text(f"SELECT {id_col}, {name_col} FROM {table}")
        ).fetchall()
    return {r[1]: r[0] for r in rows}


def run():
    print("═══ Load: Events ═══")

    # ── Venues ──────────────────────────────────────────────────────────────
    v_path = CLEAN_DIR / "venues.csv"
    if v_path.exists():
        df = pd.read_csv(v_path)
        execute_sql(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_venues_name ON venues (venue_name);"
        )
        rows = []
        for _, r in df.iterrows():
            rows.append(
                {
                    "venue_name": r["venue_name"],
                    "venue_address": r.get("venue_address"),
                    "capacity": int(r["capacity"])
                    if pd.notna(r.get("capacity"))
                    else None,
                }
            )
        execute_values_upsert(
            table="venues",
            columns=["venue_name", "venue_address", "capacity"],
            rows=rows,
            conflict_columns=["venue_name"],
            update_columns=["venue_address", "capacity"],
        )
        print(f"  Upserted {len(rows)} venues")

    # ── Managers ────────────────────────────────────────────────────────────
    m_path = CLEAN_DIR / "managers.csv"
    if m_path.exists():
        df = pd.read_csv(m_path)
        execute_sql(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_managers_name "
            "ON managers (manager_name);"
        )
        rows = []
        for _, r in df.iterrows():
            rows.append(
                {
                    "manager_name": r["manager_name"],
                    "manager_phone": r.get("manager_phone"),
                }
            )
        execute_values_upsert(
            table="managers",
            columns=["manager_name", "manager_phone"],
            rows=rows,
            conflict_columns=["manager_name"],
            update_columns=["manager_phone"],
        )
        print(f"  Upserted {len(rows)} managers")

    # ── Events ──────────────────────────────────────────────────────────────
    ev_path = CLEAN_DIR / "events.csv"
    if not ev_path.exists():
        print("  ⚠ events.csv not found")
        return

    venue_map = _get_map("venues", "venue_name", "venue_id")
    manager_map = _get_map("managers", "manager_name", "manager_id")
    artist_map = _get_map("artists", "stage_name", "artist_id")

    execute_sql(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_events_name_date "
        "ON events (event_name, event_date);"
    )

    df = pd.read_csv(ev_path)
    event_rows = []
    performer_links = []
    for _, r in df.iterrows():
        ename = r.get("event_name")
        edate = r.get("event_date")
        if not ename or pd.isna(edate):
            continue

        vid = venue_map.get(r.get("venue_name"))
        mid = manager_map.get(r.get("manager_name"))

        event_rows.append(
            {
                "event_name": ename,
                "event_date": edate,
                "venue_id": vid,
                "manager_id": mid,
                "status": str(r.get("status", "SCHEDULED")).upper(),
            }
        )

        # Track artist link for event_performers
        aname = r.get("artist_name")
        if aname:
            aid = artist_map.get(aname)
            if aid:
                performer_links.append(
                    {
                        "event_name": ename,
                        "event_date": edate,
                        "artist_id": aid,
                    }
                )

    execute_values_upsert(
        table="events",
        columns=["event_name", "event_date", "venue_id", "manager_id", "status"],
        rows=event_rows,
        conflict_columns=["event_name", "event_date"],
        update_columns=["venue_id", "manager_id", "status"],
    )
    print(f"  Upserted {len(event_rows)} events")

    # ── Event performers ────────────────────────────────────────────────────
    if performer_links:
        event_map = {}
        engine = get_engine()
        with engine.connect() as conn:
            rows = conn.execute(
                text("SELECT event_id, event_name, event_date FROM events")
            ).fetchall()
        for r in rows:
            event_map[(r[1], str(r[2])[:10])] = r[0]

        perf_rows = []
        for p in performer_links:
            eid = event_map.get((p["event_name"], str(p["event_date"])[:10]))
            if eid:
                perf_rows.append(
                    {
                        "event_id": eid,
                        "artist_id": p["artist_id"],
                    }
                )

        if perf_rows:
            execute_values_upsert(
                table="event_performers",
                columns=["event_id", "artist_id"],
                rows=perf_rows,
                conflict_columns=["event_id", "artist_id"],
            )
            print(f"  Upserted {len(perf_rows)} event_performers")

    print("═══ Events load complete ═══\n")


if __name__ == "__main__":
    run()
