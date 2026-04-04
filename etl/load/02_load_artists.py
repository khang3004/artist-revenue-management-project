"""
Load Step 2: Load Artists + ISA Sub-types
1. Resolves label_id from labels table
2. UPSERT into artists (using stage_name as conflict key)
3. INSERT INTO ISA sub-type tables

Updated for MusicBrainz-first model (no spotify_id).
"""

import json
import pandas as pd
from sqlalchemy import text
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import CLEAN_DIR
from load.loader import get_engine, execute_values_upsert, execute_sql


def _create_stage_name_index():
    execute_sql(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_artists_stage_name "
        "ON artists (stage_name);"
    )


def _get_label_map() -> dict:
    engine = get_engine()
    with engine.connect() as conn:
        rows = conn.execute(text("SELECT label_id, name FROM labels")).fetchall()
    return {r[1]: r[0] for r in rows}


def _get_artist_map() -> dict:
    engine = get_engine()
    with engine.connect() as conn:
        rows = conn.execute(
            text("SELECT artist_id, stage_name FROM artists")
        ).fetchall()
    return {r[1]: r[0] for r in rows}


def run():
    print("═══ Load: Artists ═══")

    path = CLEAN_DIR / "artists.csv"
    if not path.exists():
        print("  ⚠ artists.csv not found")
        return

    _create_stage_name_index()
    label_map = _get_label_map()

    df = pd.read_csv(path)
    rows = []
    for _, r in df.iterrows():
        label_name = r.get("label_name")
        label_id = label_map.get(label_name) if pd.notna(label_name) else None

        md = {}
        if pd.notna(r.get("mbid")):
            md["mbid"] = r["mbid"]
        if pd.notna(r.get("country")):
            md["country"] = r["country"]
        if pd.notna(r.get("genre")):
            md["genre"] = r["genre"]
        # Stable social links derived from stage_name (no randomness)
        slug = r["stage_name"].lower().replace(" ", "").replace(".", "")
        md["social_links"] = {
            "instagram": f"https://instagram.com/{slug}",
            "tiktok": f"https://tiktok.com/@{slug}",
            "youtube": f"https://youtube.com/@{slug}",
        }

        rows.append({
            "stage_name": r["stage_name"],
            "full_name": r.get("full_name") if pd.notna(r.get("full_name")) else None,
            "debut_date": r.get("debut_date") if pd.notna(r.get("debut_date")) else None,
            "birthday": r.get("birthday") if pd.notna(r.get("birthday")) else None,
            "label_id": label_id,
            "metadata": json.dumps(md) if md else None,
        })

    execute_values_upsert(
        table="artists",
        columns=["stage_name", "full_name", "debut_date", "birthday", "label_id", "metadata"],
        rows=rows,
        conflict_columns=["stage_name"],
        update_columns=["full_name", "debut_date", "birthday", "label_id", "metadata"],
    )
    print(f"  Upserted {len(rows)} artists")

    # ── ISA sub-types ───────────────────────────────────────────────────────
    artist_map = _get_artist_map()

    artist_roles_rows = []
    solo_rows, band_rows, composer_rows, producer_rows = [], [], [], []

    for _, r in df.iterrows():
        sn = r["stage_name"]
        aid = artist_map.get(sn)
        if aid is None:
            continue
        
        atype = r.get("artist_type", "solo")
        
        # Every artist gets a role in artist_roles (junction table)
        artist_roles_rows.append({
            "artist_id": aid,
            "role": atype
        })

        if atype == "solo":
            label_id = label_map.get(r.get("label_name")) if pd.notna(r.get("label_name")) else None
            solo_rows.append({"artist_id": aid, "label_id": label_id})
        elif atype == "band":
            band_rows.append({
                "artist_id": aid,
                "formation_date": r.get("debut_date") if pd.notna(r.get("debut_date")) else None,
                "is_active": True,
            })
        elif atype == "composer":
            composer_rows.append({"artist_id": aid})
        elif atype == "producer":
            producer_rows.append({"artist_id": aid})

    if artist_roles_rows:
        # For ON CONFLICT DO NOTHING, pass None for update_columns
        execute_values_upsert("artist_roles", ["artist_id", "role"],
                              artist_roles_rows, ["artist_id", "role"], None)
        print(f"  Upserted {len(artist_roles_rows)} artist_roles")

    if band_rows:
        execute_values_upsert("bands", ["artist_id", "formation_date", "is_active"],
                              band_rows, ["artist_id"], ["formation_date", "is_active"])
        print(f"  Upserted {len(band_rows)} bands")

    if composer_rows:
        execute_values_upsert("composers", ["artist_id"],
                              composer_rows, ["artist_id"], None)
        print(f"  Upserted {len(composer_rows)} composers")

    if producer_rows:
        execute_values_upsert("producers", ["artist_id"],
                              producer_rows, ["artist_id"], None)
        print(f"  Upserted {len(producer_rows)} producers")

    print("═══ Artists load complete ═══\n")


if __name__ == "__main__":
    run()
