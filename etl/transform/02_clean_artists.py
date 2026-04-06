"""
Transform Step 2: Clean & Classify Artists
Reads MusicBrainz artist data and maps type / label.

Output → data_lake/clean/artists.csv
"""

import json
import pandas as pd
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import MUSICBRAINZ_RAW, CLEAN_DIR


import random

# V-Pop genre pool — deterministically assigned from mbid so re-runs are stable
_VPOP_GENRES = [
    "V-Pop",
    "Ballad",
    "R&B",
    "Hip-hop",
    "Pop",
    "EDM",
    "Indie",
    "Dance-Pop",
    "Alternative",
    "Folk",
]


def _assign_genre(mbid: str) -> str:
    """Deterministic genre from mbid (no randomness → stable across re-runs)."""
    seed = int(mbid.replace("-", "")[:8], 16)
    return _VPOP_GENRES[seed % len(_VPOP_GENRES)]


def _map_mb_type(mb_type: str | None) -> str:
    """Map MusicBrainz type → DB enum, injecting mock roles."""
    if mb_type is None:
        return random.choices(
            ["solo", "composer", "producer"], weights=[0.8, 0.1, 0.1]
        )[0]
    t = mb_type.lower()
    if t == "group":
        return "band"
    if t == "person":
        # Randomly assign someone as solo, composer or producer to mock roles
        return random.choices(
            ["solo", "composer", "producer"], weights=[0.7, 0.15, 0.15]
        )[0]
    return "solo"


def run():
    print("═══ Transform: Artists ═══")

    mb_path = MUSICBRAINZ_RAW / "artists.json"
    if not mb_path.exists():
        print("  ⚠ artists.json not found; run extract first.")
        return

    with open(mb_path, "r", encoding="utf-8") as f:
        mb_artists = json.load(f)

    records = []
    seen = set()
    for art in mb_artists:
        mbid = art.get("mbid")
        if not mbid or mbid in seen:
            continue
        seen.add(mbid)

        name = art.get("name", "").strip()
        if not name:
            continue

        # Derive label name from first release (if any)
        label_name = None
        releases = art.get("releases", [])
        for rel in releases:
            ln = rel.get("label_name")
            if ln:
                label_name = " ".join(ln.strip().split()).title()
                break

        raw_type = art.get("type")
        mb_t = raw_type.lower() if raw_type else ""

        def _format_date(d: str | None) -> str | None:
            if not d:
                return None
            dstr = str(d).strip()
            if len(dstr) == 4:
                return f"{dstr}-01-01"
            elif len(dstr) == 7:
                return f"{dstr}-01"
            return dstr

        b_date_raw = art.get("begin_date")
        if mb_t == "person":
            bday = _format_date(b_date_raw)
            debut = None
        elif mb_t == "group":
            bday = None
            debut = _format_date(b_date_raw)
        else:
            bday = None
            debut = _format_date(b_date_raw)

        records.append(
            {
                "mbid": mbid,
                "stage_name": name,
                "full_name": art.get("sort_name") or name,
                "artist_type": _map_mb_type(art.get("type")),
                "debut_date": debut,
                "birthday": bday,
                "label_name": label_name,
                "country": art.get("country"),
                "genre": _assign_genre(mbid),
            }
        )

    df = pd.DataFrame(records)
    if len(df) > 0:
        df = df.drop_duplicates(subset=["mbid"])
        df["debut_date"] = pd.to_datetime(df["debut_date"], errors="coerce")

    df.to_csv(CLEAN_DIR / "artists.csv", index=False)
    print(f"  Saved artists.csv ({len(df)} artists)")
    print("═══ Artists transform complete ═══\n")


if __name__ == "__main__":
    run()
