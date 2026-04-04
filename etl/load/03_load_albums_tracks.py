"""
Load Step 3: Load Albums & Tracks
Uses MusicBrainz artist_mbid → stage_name → DB artist_id for resolution.
Albums use (title, artist_id) as conflict key.
Tracks use ISRC as conflict key.
"""

import pandas as pd
from sqlalchemy import text
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import CLEAN_DIR
from load.loader import get_engine, execute_sql, execute_values_upsert


def _build_mbid_to_db_artist_map(df_artists_csv) -> dict:
    """Map artist_mbid → DB artist_id via stage_name."""
    engine = get_engine()
    with engine.connect() as conn:
        rows = conn.execute(
            text("SELECT artist_id, stage_name FROM artists")
        ).fetchall()
    name_to_id = {r[1]: r[0] for r in rows}

    mbid_to_db = {}
    for _, r in df_artists_csv.iterrows():
        mbid = r.get("mbid")
        sn = r.get("stage_name")
        if pd.notna(mbid) and sn and sn in name_to_id:
            mbid_to_db[mbid] = name_to_id[sn]
    return mbid_to_db


def _get_album_map() -> dict:
    engine = get_engine()
    with engine.connect() as conn:
        rows = conn.execute(
            text("SELECT album_id, title, artist_id FROM albums")
        ).fetchall()
    return {(r[1], r[2]): r[0] for r in rows}


def run():
    print("═══ Load: Albums & Tracks ═══")

    alb_path = CLEAN_DIR / "albums.csv"
    trk_path = CLEAN_DIR / "tracks.csv"
    art_path = CLEAN_DIR / "artists.csv"
    for p in [alb_path, trk_path, art_path]:
        if not p.exists():
            print(f"  ⚠ {p.name} not found")
            return

    df_artists = pd.read_csv(art_path)
    mbid_to_db = _build_mbid_to_db_artist_map(df_artists)

    # ── Albums ──────────────────────────────────────────────────────────────
    execute_sql(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_albums_title_artist "
        "ON albums (title, artist_id);"
    )

    df_albums = pd.read_csv(alb_path)
    album_rows = []
    release_mbid_to_title_artist = {}

    for _, r in df_albums.iterrows():
        artist_mbid = r.get("artist_mbid")
        aid = mbid_to_db.get(artist_mbid)
        if aid is None:
            continue
        title = str(r.get("title", "")).strip()[:200]
        rd = r.get("release_date")
        if pd.isna(rd):
            rd = "1970-01-01"

        album_rows.append({
            "title": title,
            "release_date": rd,
            "artist_id": aid,
        })
        release_mbid = r.get("release_mbid")
        if pd.notna(release_mbid):
            release_mbid_to_title_artist[release_mbid] = (title, aid)

    execute_values_upsert(
        table="albums",
        columns=["title", "release_date", "artist_id"],
        rows=album_rows,
        conflict_columns=["title", "artist_id"],
        update_columns=["release_date"],
    )
    print(f"  Upserted {len(album_rows)} albums")

    # ── Tracks ──────────────────────────────────────────────────────────────
    album_map = _get_album_map()

    # Build a mapping from artist_mbid → first album_id in DB
    # (since MB recordings don't carry release info directly)
    artist_to_album = {}
    for (title, aid), album_id in album_map.items():
        if aid not in artist_to_album:
            artist_to_album[aid] = album_id

    df_tracks = pd.read_csv(trk_path)
    track_rows = []
    for _, r in df_tracks.iterrows():
        isrc = r.get("isrc")
        if pd.isna(isrc) or not str(isrc).strip():
            continue

        artist_mbid = r.get("artist_mbid")
        db_artist_id = mbid_to_db.get(artist_mbid)
        if db_artist_id is None:
            continue

        db_album_id = artist_to_album.get(db_artist_id)
        if db_album_id is None:
            continue

        track_rows.append({
            "isrc": str(isrc).strip(),
            "title": str(r.get("title", "")).strip(),
            "duration_seconds": int(r["duration_seconds"]) if pd.notna(r.get("duration_seconds")) else 180,
            "album_id": db_album_id,
            "play_count": int(r.get("play_count", 0)),
        })

    execute_values_upsert(
        table="tracks",
        columns=["isrc", "title", "duration_seconds", "album_id", "play_count"],
        rows=track_rows,
        conflict_columns=["isrc"],
        update_columns=["title"],
    )
    print(f"  Upserted {len(track_rows)} tracks")
    print("═══ Albums & Tracks load complete ═══\n")


if __name__ == "__main__":
    run()
