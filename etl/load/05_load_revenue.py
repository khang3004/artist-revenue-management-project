"""
Load Step 5: Load Revenue Logs + ISA sub-type detail tables
- revenue_logs (INSERT only — no dedup on log_id)
- streaming_revenue_details
- sync_revenue_details
- live_revenue_details
"""

import pandas as pd
from sqlalchemy import text
import json
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import CLEAN_DIR
from load.loader import get_engine


def run():
    print("═══ Load: Revenue Logs ═══")

    path = CLEAN_DIR / "revenue_logs.csv"
    if not path.exists():
        print("  ⚠ revenue_logs.csv not found")
        return

    df = pd.read_csv(path)
    engine = get_engine()

    # Build ISRC → track_id map
    with engine.connect() as conn:
        rows = conn.execute(text("SELECT track_id, isrc FROM tracks")).fetchall()
    isrc_map = {r[1]: r[0] for r in rows}

    # Build event_name → event_id map (for live revenue)
    with engine.connect() as conn:
        rows = conn.execute(
            text("SELECT event_id, event_name FROM events")
        ).fetchall()
    event_name_map = {r[1]: r[0] for r in rows}

    streaming_count = 0
    sync_count = 0
    live_count = 0

    # Process in chunks to avoid Neon serverless connection timeouts
    CHUNK = 200
    rows_list = list(df.iterrows())

    for chunk_start in range(0, len(rows_list), CHUNK):
        chunk = rows_list[chunk_start: chunk_start + CHUNK]
        with engine.begin() as conn:
            for _, r in chunk:
                rev_type = r.get("revenue_type")
                isrc = r.get("isrc")
                track_id = isrc_map.get(isrc) if isinstance(isrc, str) else None

                # Insert parent revenue_log
                result = conn.execute(
                    text("""
                        INSERT INTO revenue_logs
                            (track_id, source, amount, log_date, revenue_type, raw_data)
                        VALUES (:track_id, :source, :amount, :log_date, :revenue_type, :raw_data)
                        RETURNING log_id
                    """),
                    {
                        "track_id": track_id,
                        "source": r.get("source", "unknown"),
                        "amount": float(r.get("amount", 0)),
                        "log_date": r.get("log_date"),
                        "revenue_type": rev_type,
                        "raw_data": None,
                    },
                )
                log_id = result.fetchone()[0]

                # Insert ISA child
                if rev_type == "STREAMING":
                    conn.execute(
                        text("""
                            INSERT INTO streaming_revenue_details
                                (log_id, stream_count, per_stream_rate, platform)
                            VALUES (:log_id, :stream_count, :per_stream_rate, :platform)
                        """),
                        {
                            "log_id": log_id,
                            "stream_count": int(r.get("stream_count", 0)),
                            "per_stream_rate": float(r.get("per_stream_rate", 0)),
                            "platform": r.get("platform", "Unknown"),
                        },
                    )
                    streaming_count += 1

                elif rev_type == "SYNC":
                    conn.execute(
                        text("""
                            INSERT INTO sync_revenue_details
                                (log_id, licensee_name, usage_type)
                            VALUES (:log_id, :licensee_name, :usage_type)
                        """),
                        {
                            "log_id": log_id,
                            "licensee_name": r.get("licensee_name", r.get("licenses_name", "Unknown")),
                            "usage_type": r.get("usage_type", "Unknown"),
                        },
                    )
                    sync_count += 1

                elif rev_type == "LIVE":
                    eid = event_name_map.get(r.get("event_name"))
                    conn.execute(
                        text("""
                            INSERT INTO live_revenue_details
                                (log_id, event_id, ticket_sold)
                            VALUES (:log_id, :event_id, :ticket_sold)
                        """),
                        {
                            "log_id": log_id,
                            "event_id": eid,
                            "ticket_sold": int(r.get("ticket_sold", 0)) if pd.notna(r.get("ticket_sold")) else None,
                        },
                    )
                    live_count += 1

    print(f"  Loaded {streaming_count} streaming + {sync_count} sync + {live_count} live = {streaming_count + sync_count + live_count} total")
    print("═══ Revenue load complete ═══\n")


if __name__ == "__main__":
    run()
