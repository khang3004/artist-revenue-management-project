"""
crawlers/ticketbox/crawl_ticketbox.py
======================================
Crawler for V-Pop live event data from Ticketbox.

Strategy:
  1. Try to scrape ticketbox.vn/vi/events/music (best-effort HTML scrape).
  2. If scraped events < 10 (blocked / layout changed), generate realistic
     mock events using artist names from the MusicBrainz crawl output.
     → NO Spotify dependency.

Output → etl/data_lake/raw/ticketbox/events.json

Usage:
    python -m crawlers.ticketbox.crawl_ticketbox
    # Run AFTER crawl_musicbrainz.py so that artists.json is available.
"""

import json
import random
import datetime
from pathlib import Path

import requests
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import os

# ── Config ────────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
load_dotenv(PROJECT_ROOT / ".env")

TICKET_PRICE_VND_DEFAULT = 500_000  # VND

MB_ARTISTS_PATH  = PROJECT_ROOT / "etl" / "data_lake" / "raw" / "musicbrainz" / "artists.json"
OUTPUT_DIR       = PROJECT_ROOT / "etl" / "data_lake" / "raw" / "ticketbox"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
}

# ── Static venue / manager pools (used for mock fallback) ─────────────────────
MOCK_VENUES = [
    {"venue_name": "Nhà hát Hòa Bình",           "address": "240 Đ. 3 Tháng 2, Q.10, TP.HCM",    "capacity": 2500},
    {"venue_name": "Nhà hát Bến Thành",           "address": "6 Mạc Đĩnh Chi, Q.1, TP.HCM",       "capacity": 1200},
    {"venue_name": "Trung tâm Hội nghị Quốc gia", "address": "57 Phạm Hùng, Hà Nội",              "capacity": 4000},
    {"venue_name": "Nhà hát Lớn Hà Nội",          "address": "1 Tràng Tiền, Hoàn Kiếm, Hà Nội",  "capacity": 600},
    {"venue_name": "SVĐ Phú Thọ",                 "address": "1 Lữ Gia, Q.11, TP.HCM",            "capacity": 15000},
    {"venue_name": "GEM Center",                   "address": "8 Nguyễn Bỉnh Khiêm, Q.1, TP.HCM", "capacity": 1500},
    {"venue_name": "White Palace",                 "address": "194 Hoàng Văn Thụ, Phú Nhuận, HCM", "capacity": 3000},
    {"venue_name": "Nhà Văn hóa Thanh Niên",      "address": "4 Phạm Ngọc Thạch, Q.1, TP.HCM",   "capacity": 800},
]

MOCK_MANAGERS = [
    {"manager_name": "Nguyễn Văn An",   "phone": "0901234567"},
    {"manager_name": "Trần Thị Bình",   "phone": "0912345678"},
    {"manager_name": "Lê Hoàng Minh",   "phone": "0923456789"},
    {"manager_name": "Phạm Thanh Hà",   "phone": "0934567890"},
    {"manager_name": "Võ Quốc Trung",   "phone": "0945678901"},
]

EVENT_TEMPLATES = [
    "{artist} Live Concert",
    "{artist} Showcase — Fan Meeting",
    "V-Pop Night ft. {artist}",
    "{artist} — Music Journey",
    "Year-End Gala ft. {artist}",
]


# ── Scraper ───────────────────────────────────────────────────────────────────

def _try_scrape_ticketbox() -> list:
    """Best-effort HTML scrape of ticketbox.vn music events."""
    events = []
    try:
        for url_path in ["/vi/events/music", "/events/music"]:
            resp = requests.get(
                f"https://ticketbox.vn{url_path}", headers=HEADERS, timeout=15
            )
            if resp.status_code != 200:
                continue
            soup = BeautifulSoup(resp.text, "html.parser")
            cards = soup.select(".event-card, .event-item, .card, article")
            for card in cards[:30]:
                title_el  = card.select_one("h3, h4, .event-title, .card-title, a[title]")
                date_el   = card.select_one(".event-date, .date, time")
                venue_el  = card.select_one(".event-venue, .venue, .location")
                events.append({
                    "event_name": title_el.get_text(strip=True) if title_el else None,
                    "event_date": date_el.get_text(strip=True)  if date_el  else None,
                    "venue_name": venue_el.get_text(strip=True) if venue_el else None,
                    "source":     "ticketbox",
                })
            if events:
                break
    except Exception as e:
        print(f"  ⚠ Ticketbox scrape failed: {e}")
    return [e for e in events if e.get("event_name")]


# ── Mock event generator ───────────────────────────────────────────────────────

def _generate_mock_events(artist_names: list) -> list:
    """
    Generate realistic mock V-Pop live events.
    Status values match the `event_status_enum` ENUM in the DB: COMPLETED / SCHEDULED.
    """
    events = []
    base_date = datetime.date.today() - datetime.timedelta(days=365)

    for name in artist_names[:40]:
        for _ in range(random.randint(1, 3)):
            venue   = random.choice(MOCK_VENUES)
            manager = random.choice(MOCK_MANAGERS)
            delta      = random.randint(0, 730)
            event_date = base_date + datetime.timedelta(days=delta)
            # Match DB ENUM: COMPLETED / SCHEDULED (uppercase)
            status = "COMPLETED" if event_date < datetime.date.today() else "SCHEDULED"

            events.append({
                "event_name":       random.choice(EVENT_TEMPLATES).format(artist=name),
                "event_date":       event_date.isoformat(),
                "venue_name":       venue["venue_name"],
                "venue_address":    venue["address"],
                "venue_capacity":   venue["capacity"],
                "manager_name":     manager["manager_name"],
                "manager_phone":    manager["phone"],
                "ticket_price_vnd": TICKET_PRICE_VND_DEFAULT + random.randint(-200_000, 500_000),
                "ticket_sold":      random.randint(
                    int(venue["capacity"] * 0.4),
                    venue["capacity"],
                ),
                "status":           status,
                "artist_name":      name,
                "source":           "mock",
            })
    return events


# ── Main ──────────────────────────────────────────────────────────────────────

def run():
    print("═══ Ticketbox V-Pop Event Crawler ═══")

    events = _try_scrape_ticketbox()
    print(f"  Scraped {len(events)} events from Ticketbox.")

    if len(events) < 10:
        print("  → Insufficient scraped data — switching to mock generation …")
        if MB_ARTISTS_PATH.exists():
            with open(MB_ARTISTS_PATH, "r", encoding="utf-8") as f:
                mb_artists = json.load(f)
            names = [a["name"] for a in mb_artists if a.get("name")]
            mock = _generate_mock_events(names)
            events.extend(mock)
            print(f"  Generated {len(mock)} mock events from MusicBrainz artist list.")
        else:
            print(
                "  ⚠ artists.json not found. "
                "Run crawlers/musicbrainz/crawl_musicbrainz.py first."
            )

    out_path = OUTPUT_DIR / "events.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(events, f, ensure_ascii=False, indent=2)
    print(f"  ✓ events.json  ({len(events)} records) → {out_path}")
    print("═══ Ticketbox crawl complete ═══\n")


if __name__ == "__main__":
    run()
