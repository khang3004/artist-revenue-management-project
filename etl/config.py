"""
ETL Pipeline Configuration
All paths and constants used by the Transform and Load phases.

NOTE: Crawling is handled separately by the `crawlers/` package.
      Run the crawlers FIRST, then run this ETL pipeline.
      - crawlers/musicbrainz/crawl_musicbrainz.py
      - crawlers/ticketbox/crawl_ticketbox.py
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# ── Load .env from project root ──────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")

# ── Data Lake paths ──────────────────────────────────────────────────────────
DATA_LAKE  = Path(__file__).resolve().parent / "data_lake"
RAW_DIR    = DATA_LAKE / "raw"
CLEAN_DIR  = DATA_LAKE / "clean"

MUSICBRAINZ_RAW = RAW_DIR / "musicbrainz"
TICKETBOX_RAW   = RAW_DIR / "ticketbox"

# Ensure directories exist
for d in [MUSICBRAINZ_RAW, TICKETBOX_RAW, CLEAN_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# ── Database ─────────────────────────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL", "")

# ── MusicBrainz (used only for metadata in transform phase) ──────────────────
MB_APP_NAME    = os.getenv("MB_APP_NAME",    "artist-revenue-etl")
MB_APP_VERSION = os.getenv("MB_APP_VERSION", "1.0")
MB_CONTACT     = os.getenv("MB_CONTACT",     "etl@example.com")

# ── Revenue constants ────────────────────────────────────────────────────────
PER_STREAM_RATE_USD      = 0.004   # $0.004 per stream (industry average)
SYNC_LICENSE_BASE_USD    = 5000    # base sync license fee for mock revenue
TICKET_PRICE_VND_DEFAULT = 500_000 # VND — used in mock event fallback

# ── Contract split defaults (must sum ≤ 1.0) ────────────────────────────────
DEFAULT_SPLITS = {
    "performer":  0.50,
    "composer":   0.30,
    "producer":   0.20,
}
