"""
Transform Step 5: Build Revenue Logs (Mock)
Creates realistic revenue_logs from YouTube view counts (streaming),
synthetic sync licensing, and event ticket sales (live).

Output → data_lake/clean/revenue_logs.csv
"""

import json
import random
import datetime
import pandas as pd
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import (
    CLEAN_DIR,
    PER_STREAM_RATE_USD, SYNC_LICENSE_BASE_USD,
)


def _build_streaming_revenue() -> list:
    """Mock streaming revenue based on tracks."""
    tracks_path = CLEAN_DIR / "tracks.csv"
    if not tracks_path.exists():
        return []
    df = pd.read_csv(tracks_path)

    rows = []
    for _, t in df.iterrows():
        isrc = t.get("isrc")
        views = t.get("play_count", 0)
        if not isrc or views == 0:
            continue

        # Split views into monthly buckets (last 12 months)
        for month_offset in range(12):
            dt = datetime.date.today().replace(day=1) - datetime.timedelta(days=30 * month_offset)
            portion = random.uniform(0.05, 0.15)
            stream_count = int(views * portion)
            amount = round(stream_count * PER_STREAM_RATE_USD, 4)

            rows.append({
                "isrc": isrc,
                "source": "Spotify", # Changed from YouTube
                "amount": amount,
                "log_date": dt.isoformat(),
                "revenue_type": "STREAMING",
                "stream_count": stream_count,
                "per_stream_rate": PER_STREAM_RATE_USD,
                "platform": "Spotify",
            })
    return rows


def _build_sync_revenue() -> list:
    """Synthetic sync revenue for a subset of tracks."""
    tracks_path = CLEAN_DIR / "tracks.csv"
    if not tracks_path.exists():
        return []
    df = pd.read_csv(tracks_path)

    rows = []
    sample = df.sample(n=min(15, len(df)), random_state=42)
    usage_types = ["TV Drama", "Film OST", "Advertisement", "Game OST", "Web Series"]

    for _, t in sample.iterrows():
        dt = datetime.date.today() - datetime.timedelta(days=random.randint(30, 365))
        amount = SYNC_LICENSE_BASE_USD + random.randint(-2000, 8000)
        rows.append({
            "isrc": t.get("isrc"),
            "source": "sync_licensing",
            "amount": round(amount, 4),
            "log_date": dt.isoformat(),
            "revenue_type": "SYNC",
            "licensee_name": f"License-{random.randint(1000, 9999)}",
            "usage_type": random.choice(usage_types),
        })
    return rows


def _build_live_revenue() -> list:
    """Revenue from events (ticket sales)."""
    ev_path = CLEAN_DIR / "events.csv"
    if not ev_path.exists():
        return []
    df = pd.read_csv(ev_path)

    rows = []
    for _, ev in df.iterrows():
        price = ev.get("ticket_price_vnd", 500_000)
        sold = ev.get("ticket_sold", 0)
        if pd.isna(price) or pd.isna(sold):
            continue
        amount = round(price * sold / 24_000, 4)  # rough VND → USD
        rows.append({
            "isrc": None,  # live revenue is not track-specific
            "source": "live_performance",
            "amount": amount,
            "log_date": ev.get("event_date"),
            "revenue_type": "LIVE",
            "event_name": ev.get("event_name"),
            "ticket_sold": int(sold),
        })
    return rows


def run():
    print("═══ Transform: Revenue Logs ═══")

    streaming = _build_streaming_revenue()
    print(f"  Streaming rows: {len(streaming)}")

    sync = _build_sync_revenue()
    print(f"  Sync rows: {len(sync)}")

    live = _build_live_revenue()
    print(f"  Live rows: {len(live)}")

    all_revenue = streaming + sync + live
    df = pd.DataFrame(all_revenue)
    df.to_csv(CLEAN_DIR / "revenue_logs.csv", index=False)
    print(f"  Saved revenue_logs.csv ({len(df)} total rows)")
    print("═══ Revenue transform complete ═══\n")


if __name__ == "__main__":
    run()
