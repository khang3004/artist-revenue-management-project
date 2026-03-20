"""
Transform Step 4: Clean Events
Unchanged logic — reads ticketbox events.json.

Output → data_lake/clean/{venues,managers,events}.csv
"""

import json
import pandas as pd
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import TICKETBOX_RAW, CLEAN_DIR


def run():
    print("═══ Transform: Events ═══")

    path = TICKETBOX_RAW / "events.json"
    if not path.exists():
        print("  ⚠ events.json not found; run extract first.")
        return

    with open(path, "r", encoding="utf-8") as f:
        raw = json.load(f)

    if not raw:
        print("  ⚠ events.json is empty")
        return

    # ── Venues ──
    venues = {}
    for ev in raw:
        vn = ev.get("venue_name")
        if vn and vn not in venues:
            venues[vn] = {
                "venue_name": vn,
                "address": ev.get("venue_address"),
                "capacity": ev.get("venue_capacity"),
            }
    df_venues = pd.DataFrame(venues.values())
    df_venues.to_csv(CLEAN_DIR / "venues.csv", index=False)
    print(f"  Saved venues.csv ({len(df_venues)} venues)")

    # ── Managers ──
    managers = {}
    for ev in raw:
        mn = ev.get("manager_name")
        if mn and mn not in managers:
            managers[mn] = {
                "manager_name": mn,
                "phone_manager": ev.get("manager_phone"),
            }
    df_managers = pd.DataFrame(managers.values())
    df_managers.to_csv(CLEAN_DIR / "managers.csv", index=False)
    print(f"  Saved managers.csv ({len(df_managers)} managers)")

    # ── Events ──
    events = []
    for ev in raw:
        events.append({
            "event_name": ev.get("event_name"),
            "event_date": ev.get("event_date"),
            "venue_name": ev.get("venue_name"),
            "manager_name": ev.get("manager_name"),
            "status": ev.get("status", "Scheduled"),
            "ticket_price_vnd": ev.get("ticket_price_vnd"),
            "ticket_sold": ev.get("ticket_sold"),
            "artist_name": ev.get("artist_name"),
        })
    df_events = pd.DataFrame(events)
    df_events["event_date"] = pd.to_datetime(df_events["event_date"], errors="coerce")
    df_events = df_events.dropna(subset=["event_name", "event_date"])
    df_events = df_events.drop_duplicates(subset=["event_name", "event_date"])
    df_events.to_csv(CLEAN_DIR / "events.csv", index=False)
    print(f"  Saved events.csv ({len(df_events)} events)")
    print("═══ Events transform complete ═══\n")


if __name__ == "__main__":
    run()
