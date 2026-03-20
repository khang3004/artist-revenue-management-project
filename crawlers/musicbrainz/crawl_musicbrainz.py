"""
crawlers/musicbrainz/crawl_musicbrainz.py
==========================================
Crawler for V-Pop MusicBrainz data (standalone, no external API dependency).

Strategy:
  1. Seed-list lookup: well-known V-Pop artist names → exact MBID
  2. Area search: all artists with area="Vietnam" from MusicBrainz
  3. For each artist: fetch releases (albums), recordings (ISRCs), relationships (roles)

Output → etl/data_lake/raw/musicbrainz/{artists,labels,recordings,relationships}.json

Usage:
    python -m crawlers.musicbrainz.crawl_musicbrainz
    # or from project root:
    uv run -m crawlers.musicbrainz.crawl_musicbrainz
"""

import json
import time
from pathlib import Path
import musicbrainzngs as mb
from tqdm import tqdm
from dotenv import load_dotenv
import os

# ── Config ────────────────────────────────────────────────────────────────────
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
load_dotenv(PROJECT_ROOT / ".env")

MB_APP_NAME = os.getenv("MB_APP_NAME", "artist-revenue-etl")
MB_APP_VERSION = os.getenv("MB_APP_VERSION", "1.0")
MB_CONTACT = os.getenv("MB_CONTACT", "etl@example.com")

OUTPUT_DIR = PROJECT_ROOT / "etl" / "data_lake" / "raw" / "musicbrainz"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ── Well-known V-Pop seed names (for discovery bootstrap) ─────────────────────
VPOP_SEED_NAMES = [
    # ── VŨ TRỤ "ANH TRAI SAY HI" (ATSH) ─────────────────
    "RHYDER",
    "Negav",
    "Pháp Kiều",
    "Captain",
    "HURRYKNG",
    "WEAN",
    "Dương Domic",
    "JSOL",
    "Quân A.P",
    "Anh Tú Atus",
    "Song Luân",
    "Lou Hoàng",
    "Isaac",
    "Ali Hoàng Dương",
    "Gemini Hùng Huỳnh",
    # ── VŨ TRỤ "ANH TRAI VƯỢT NGÀN CHÔNG GAI" (ATVNCG) ──
    "SOOBIN",
    "Kay Trần",
    "S.T Sơn Thạch",
    "Bùi Công Nam",
    "Rhymastic",
    "Cường Seven",
    "Thanh Duy",
    "Trọng Hiếu",  #
    # ── VŨ TRỤ "CHỊ ĐẸP" & LUNAS ────────────────────────
    "Trang Pháp",
    "Huyền Baby",
    "MLee",
    "Diệp Lâm Anh",
    "Khổng Tú Quỳnh",
    "LUNAS",
    # ── GEN Z HIT-MAKERS & INDIE POP ────────────────────
    "Tăng Duy Tân",
    "GREY D",
    "Hoàng Dũng",
    "Juky San",
    "Hoàng Duyên",
    "Vũ Phụng Tiên",
    "Cầm",
    "Vũ Thanh Vân",
    "Doãn Hiếu",
    # ── RAP VIỆT (THẾ HỆ MỚI) ───────────────────────────
    "Double2T",
    "24k.Right",
    "Pháo",
    "Liu Grace",
    "OgeNus",
    "Lăng LD",
    "Ricky Star",
    "Yuno Bigboi",
    # ── PRODUCERS (CỰC QUAN TRỌNG CHO BẢNG CONTRACTS) ───
    "Hứa Kim Tuyền",
    "Masew",
    "WOKEUP",
    "2pillz",
    "Machiot",
    "Touliver",
]  # 50 Artists - Perfect for a rapid Proof of Concept (PoC)fallback


# ── Helpers ───────────────────────────────────────────────────────────────────


def _init_mb():
    mb.set_useragent(MB_APP_NAME, MB_APP_VERSION, MB_CONTACT)


def _search_artist_by_name(name: str) -> dict | None:
    """Search MusicBrainz for an artist by name; prefer exact matches."""
    try:
        result = mb.search_artists(artist=name, limit=5)
        for art in result.get("artist-list", []):
            if art.get("name", "").lower() == name.lower():
                return art
            if art.get("sort-name", "").lower() == name.lower():
                return art
        # Fallback: first result with score ≥ 80
        for art in result.get("artist-list", []):
            if int(art.get("ext:score", 0)) >= 80:
                return art
    except Exception as e:
        print(f"  ⚠ MB search '{name}': {e}")
    return None


def _search_artists_by_query(query: str, limit_cap: int = 500) -> list:
    """Search MB for artists using a strict Lucene query (paginated, capped)."""
    artists = []
    offset = 0
    while offset < limit_cap:
        try:
            result = mb.search_artists(query=query, limit=100, offset=offset)
            batch = result.get("artist-list", [])
            if not batch:
                break
            artists.extend(batch)
            offset += len(batch)
            time.sleep(1.1)
        except Exception as e:
            print(f"  ⚠ Query search offset {offset}: {e}")
            break
    return artists


def _fetch_artist_releases(mbid: str) -> list:
    """Fetch album/single/EP releases for an artist."""
    releases = []
    offset = 0
    while True:
        try:
            result = mb.browse_releases(
                artist=mbid,
                includes=["labels"],
                release_type=["album", "single", "ep"],
                limit=100,
                offset=offset,
            )
            batch = result.get("release-list", [])
            if not batch:
                break
            releases.extend(batch)
            offset += len(batch)
            time.sleep(1.1)
        except Exception as e:
            print(f"  ⚠ Releases for {mbid}: {e}")
            break
    return releases


def _fetch_artist_recordings(mbid: str, cap: int = 300) -> list:
    """Fetch recordings (with ISRCs) for an artist, capped at `cap`."""
    recordings = []
    offset = 0
    while offset < cap:
        try:
            result = mb.browse_recordings(
                artist=mbid, includes=["isrcs"], limit=100, offset=offset
            )
            batch = result.get("recording-list", [])
            if not batch:
                break
            recordings.extend(batch)
            offset += len(batch)
            time.sleep(1.1)
        except Exception as e:
            print(f"  ⚠ Recordings for {mbid}: {e}")
            break
    return recordings


def _fetch_recording_roles(recording_id: str) -> list:
    """Fetch artist-level roles for a single recording."""
    try:
        result = mb.get_recording_by_id(recording_id, includes=["artist-rels"])
        return result.get("recording", {}).get("artist-relation-list", [])
    except Exception:
        pass
    return []


# ── Main ──────────────────────────────────────────────────────────────────────


def run():
    print("═══ MusicBrainz V-Pop Crawler ═══")
    _init_mb()

    # 1. Artist discovery ──────────────────────────────────────────────────────
    print("→ Seed-list lookup …")
    discovered: dict[str, dict] = {}
    for name in tqdm(VPOP_SEED_NAMES, desc="Seed lookup"):
        art = _search_artist_by_name(name)
        if art:
            discovered[art["id"]] = art
        time.sleep(1.1)
    print(f"  Found {len(discovered)} artists from seed names.")

    print("→ Query search 'V-Pop (after 1995)' …")
    query = "area:vietnam AND begin:1995 TO *"
    for art in _search_artists_by_query(query):
        if art["id"] not in discovered:
            discovered[art["id"]] = art
    print(f"  Total unique artists after time-based query: {len(discovered)}")

    # 2. Artist details ────────────────────────────────────────────────────────
    artists_out = []
    labels_set: dict[str, dict] = {}
    all_recordings = []
    all_relationships = []

    def _save(obj, name):
        path = OUTPUT_DIR / f"{name}.json"
        with open(path, "w", encoding="utf-8") as f:
            json.dump(obj, f, ensure_ascii=False, indent=2)

    print("→ Fetching artist details, releases, recordings …")
    BATCH_SIZE = 20
    count = 0

    for mbid, art in tqdm(discovered.items(), desc="Artist details"):
        count += 1
        artist_record = {
            "mbid": mbid,
            "name": art.get("name"),
            "sort_name": art.get("sort-name"),
            "type": art.get("type"),  # Person / Group
            "country": art.get("country"),
            "begin_date": art.get("life-span", {}).get("begin"),
            "end_date": art.get("life-span", {}).get("end"),
            "disambiguation": art.get("disambiguation"),
            "releases": [],
        }
        artists_out.append(artist_record)

        # Releases + label discovery
        for rel in _fetch_artist_releases(mbid):
            label_info_list = rel.get("label-info-list", [])
            for li in label_info_list:
                lab = li.get("label")
                if lab and lab.get("name"):
                    labels_set[lab["name"]] = {
                        "mbid": lab.get("id"),
                        "name": lab["name"],
                        "country": lab.get("country"),
                    }
            artist_record["releases"].append(
                {
                    "release_mbid": rel.get("id"),
                    "title": rel.get("title"),
                    "date": rel.get("date"),
                    "status": rel.get("status"),
                    "label_name": (
                        label_info_list[0]["label"]["name"]
                        if label_info_list and label_info_list[0].get("label")
                        else None
                    ),
                }
            )

        # Recordings + ISRCs
        recordings = _fetch_artist_recordings(mbid)
        for rec in recordings:
            all_recordings.append(
                {
                    "recording_mbid": rec["id"],
                    "title": rec.get("title"),
                    "artist_mbid": mbid,
                    "artist_name": art.get("name"),
                    "length_ms": rec.get("length"),
                    "isrcs": rec.get("isrc-list", []),
                }
            )

        # Role relationships (sample first 10 recordings to stay within rate limits)
        for rec in recordings[:10]:
            for rel in _fetch_recording_roles(rec["id"]):
                all_relationships.append(
                    {
                        "recording_mbid": rec["id"],
                        "recording_title": rec.get("title"),
                        "type": rel.get("type"),
                        "target_name": rel.get("artist", {}).get("name")
                        if isinstance(rel.get("artist"), dict)
                        else None,
                        "target_mbid": rel.get("artist", {}).get("id")
                        if isinstance(rel.get("artist"), dict)
                        else None,
                        "attributes": rel.get("attribute-list", []),
                    }
                )
            time.sleep(1.1)

        # ── Batch Saving ──
        if count % BATCH_SIZE == 0:
            _save(artists_out, "artists")
            _save(list(labels_set.values()), "labels")
            _save(all_recordings, "recordings")
            _save(all_relationships, "relationships")
            # print(f"\n  [Auto-save] Checkpoint at {count} artists.")

    # 3. Final Persist ─────────────────────────────────────────────────────────
    _save(artists_out, "artists")
    _save(list(labels_set.values()), "labels")
    _save(all_recordings, "recordings")
    _save(all_relationships, "relationships")

    print(f"  ✓ artists.json        ({len(artists_out)} records)")
    print(f"  ✓ labels.json         ({len(labels_set)} records)")
    print(f"  ✓ recordings.json     ({len(all_recordings)} records)")
    print(f"  ✓ relationships.json  ({len(all_relationships)} records)")
    print("═══ MusicBrainz crawl complete ═══\n")


if __name__ == "__main__":
    run()
