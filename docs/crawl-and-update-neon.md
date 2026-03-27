# Crawl & Update Neon Guide

How to refresh the database on Neon with fresh V-Pop data from MusicBrainz and Ticketbox.

---

## Prerequisites

- Python 3.12+
- [`uv`](https://docs.astral.sh/uv/getting-started/installation/) package manager
- A Neon database with the schema already applied (migrations run)

---

## 1. Configure `.env`

Copy `.env.example` to `.env` and set your Neon connection string:

```bash
cp .env.example .env
```

Edit `.env` and update `DATABASE_URL` to your Neon project URL:

```env
DATABASE_URL=postgresql://user:password@your-project.neon.tech/dbname?sslmode=require
MB_APP_NAME=artist-revenue-etl
MB_APP_VERSION=1.0
MB_CONTACT=your@email.com
```

> `MB_CONTACT` should be a valid email — MusicBrainz requires it in the User-Agent header.

---

## 2. Install Dependencies

From the project root:

```bash
uv venv
uv pip install -r crawlers/requirements.txt
uv pip install musicbrainzngs pandas beautifulsoup4
```

---

## 3. Run the Crawlers

Run from the **project root**, in order:

### Step 1 — MusicBrainz (artists, albums, tracks)

```bash
PYTHONUTF8=1 uv run -m crawlers.musicbrainz.crawl_musicbrainz
```

**Expected time: 30–60 minutes** (rate-limited to ~1 req/sec by MusicBrainz policy).

Outputs to `etl/data_lake/raw/musicbrainz/`:
- `artists.json`
- `labels.json`
- `recordings.json`
- `relationships.json`

### Step 2 — Ticketbox (live events)

```bash
PYTHONUTF8=1 uv run -m crawlers.ticketbox.crawl_ticketbox
```

Attempts to scrape ticketbox.vn; if fewer than 10 events are scraped (site blocked or layout changed), it automatically generates realistic mock events using the artist list from Step 1.

Outputs to `etl/data_lake/raw/ticketbox/`:
- `events.json`

> Run Step 1 **before** Step 2 — the Ticketbox crawler reads `artists.json` for mock event generation.

---

## 4. Run the ETL Pipeline

Transform and load the crawled data into Neon:

```bash
PYTHONUTF8=1 uv run etl/run_etl.py
```

This runs two phases:

| Phase | Steps | What it does |
|-------|-------|--------------|
| Transform | `01` → `06` | Cleans raw JSON → normalized CSVs in `etl/data_lake/clean/` |
| Load | `01` → `06` | UPSERTs CSVs into Neon (labels → artists → albums/tracks → events → revenue → contracts) |

To run only one phase:

```bash
PYTHONUTF8=1 uv run etl/run_etl.py transform   # Phase 1 only
PYTHONUTF8=1 uv run etl/run_etl.py load        # Phase 2 only
```

---

## 5. Full Pipeline (one command)

```bash
PYTHONUTF8=1 uv run -m crawlers.musicbrainz.crawl_musicbrainz \
  && PYTHONUTF8=1 uv run -m crawlers.ticketbox.crawl_ticketbox \
  && PYTHONUTF8=1 uv run etl/run_etl.py
```

---

## Notes

- `PYTHONUTF8=1` is required on Windows to handle Vietnamese characters in artist names.
- The MusicBrainz crawler auto-saves every 20 artists — if interrupted, partial data is preserved in `data_lake/raw/musicbrainz/`. You can skip re-crawling and go straight to Step 4 (ETL only).
- The ETL load uses UPSERT — safe to re-run without creating duplicates.
- `revenue_logs` is append-only by design; re-running the load will not duplicate revenue entries if the source data is unchanged.
