#!/usr/bin/env python3
"""
ETL Pipeline Orchestrator
Runs Transform and Load phases against data already crawled to data_lake/raw/.

  Phase 1 – Transform  (raw JSON → cleaned CSV in data_lake/clean/)
  Phase 2 – Load       (clean CSV → UPSERT into PostgreSQL)

Prerequisites
─────────────
Before running this script, crawl fresh data with:
    uv run -m crawlers.musicbrainz.crawl_musicbrainz
    uv run -m crawlers.ticketbox.crawl_ticketbox

Usage
─────
    uv run run_etl.py              # transform + load
    uv run run_etl.py transform    # only Phase 1
    uv run run_etl.py load         # only Phase 2
"""

import sys
import time
import importlib
import os

# Ensure the 'etl' directory is in sys.path so modules can be found
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def _run_transform():
    print("\n╔══════════════════════════════════════╗")
    print("║   PHASE 1 — TRANSFORM               ║")
    print("╚══════════════════════════════════════╝\n")

    steps = [
        "transform.01_clean_labels",
        "transform.02_clean_artists",
        "transform.03_clean_albums_tracks",
        "transform.04_clean_events",
        "transform.05_build_revenue",
        "transform.06_build_contracts",
    ]
    for mod_name in steps:
        try:
            mod = importlib.import_module(mod_name)
            mod.run()
        except Exception as e:
            print(f"  ⚠ {mod_name} failed: {e}")
            print("  → Continuing to next transformer …\n")


def _run_load():
    print("\n╔══════════════════════════════════════╗")
    print("║   PHASE 2 — LOAD                    ║")
    print("╚══════════════════════════════════════╝\n")

    steps = [
        "load.01_load_labels",
        "load.02_load_artists",
        "load.03_load_albums_tracks",
        "load.04_load_events",
        "load.05_load_revenue",
        "load.06_load_contracts",
    ]
    for mod_name in steps:
        try:
            mod = importlib.import_module(mod_name)
            mod.run()
        except Exception as e:
            print(f" {mod_name} failed: {e}")
            print("  → Continuing to next loader …\n")


def main():
    start = time.time()
    phase = sys.argv[1].lower() if len(sys.argv) > 1 else "all"

    if phase in ("all", "transform"):
        _run_transform()
    if phase in ("all", "load"):
        _run_load()

    elapsed = time.time() - start
    print(f"\n ETL Pipeline finished in {elapsed:.1f}s")


if __name__ == "__main__":
    main()
