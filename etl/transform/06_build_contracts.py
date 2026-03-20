"""
Transform Step 6: Build Synthetic Contracts & Splits
Uses MusicBrainz relationship data (roles) to create contracts.

Output → data_lake/clean/{contracts,contract_splits,beneficiaries}.csv
"""

import json
import uuid
import pandas as pd
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import MUSICBRAINZ_RAW, CLEAN_DIR, DEFAULT_SPLITS


import random

def run():
    print("═══ Transform: Contracts & Splits ═══")

    art_path = CLEAN_DIR / "artists.csv"
    if not art_path.exists():
        print("  ⚠ artists.csv not found")
        return
    df_artists = pd.read_csv(art_path)

    trk_path = CLEAN_DIR / "tracks.csv"
    if not trk_path.exists():
        print("  ⚠ tracks.csv not found")
        return
    df_tracks = pd.read_csv(trk_path)

    # ── Generate varied contracts ───────────────────────────────────────────
    contracts = []
    contract_map = {}

    for _, row in df_artists.iterrows():
        sn = row.get("stage_name")
        ln = row.get("label_name")
        if pd.isna(ln) or not ln:
            continue
        key = (sn, ln)
        if key in contract_map:
            continue
        cid = str(uuid.uuid4())
        contract_map[key] = cid
        dd = row.get("debut_date")
        start_date = dd if pd.notna(dd) else "2020-01-01"
        
        # 1. Recording Contract
        contracts.append({
            "contract_id": cid,
            "name": f"Recording Deal — {sn} × {ln}",
            "start_date": start_date,
            "end_date": None,
            "status": "active",
            "contract_type": "recording",
            "advance_amount": random.randint(10000, 50000),
            "album_commitment_quantity": random.randint(1, 3),
            "exclusivity_years": random.randint(1, 5)
        })
        
        # 2. Distribution Contract (30% chance)
        if random.random() < 0.3:
            contracts.append({
                "contract_id": str(uuid.uuid4()),
                "name": f"Global Distribution - {sn}",
                "start_date": start_date,
                "end_date": None,
                "status": "active",
                "contract_type": "distribution",
                "territory": random.choice(["Global", "Asia-Pacific", "North America", "Europe"]),
                "distribution_fee_pct": round(random.uniform(0.1, 0.3), 4)
            })

        # 3. Publishing Contract (40% chance)
        if random.random() < 0.4:
            contracts.append({
                "contract_id": str(uuid.uuid4()),
                "name": f"Publishing Deal - {sn}",
                "start_date": start_date,
                "end_date": None,
                "status": "active",
                "contract_type": "publishing",
                "copyright_owner": ln,
                "sync_rights_included": random.choice([True, False])
            })

    print(f"  Generated {len(contracts)} contracts")

    # ── Beneficiaries ───────────────────────────────────────────────────────
    beneficiaries = []
    bene_map = {}
    bid = 1

    for _, row in df_artists.iterrows():
        sn = row.get("stage_name")
        if sn and sn not in bene_map:
            bene_map[sn] = bid
            beneficiaries.append({
                "beneficiary_id": bid,
                "beneficiary_type": "A",
                "artist_stage_name": sn,
            })
            bid += 1

    label_bene_map = {}
    labels_csv = CLEAN_DIR / "labels.csv"
    if labels_csv.exists():
        df_labels = pd.read_csv(labels_csv)
        for _, row in df_labels.iterrows():
            ln = row.get("name")
            if ln and ln not in label_bene_map:
                label_bene_map[ln] = bid
                beneficiaries.append({
                    "beneficiary_id": bid,
                    "beneficiary_type": "L",
                    "label_name": ln,
                })
                bid += 1

    print(f"  Generated {len(beneficiaries)} beneficiaries")

    # ── Contract splits ─────────────────────────────────────────────────────
    splits = []
    for _, trk in df_tracks.iterrows():
        artist_mbid = trk.get("artist_mbid")
        isrc = trk.get("isrc")
        if pd.isna(isrc) or not isrc:
            continue

        # Find the artist's stage_name by mbid
        match = df_artists[df_artists["mbid"] == artist_mbid]
        if match.empty:
            continue
        artist_row = match.iloc[0]
        sn = artist_row.get("stage_name")
        ln = artist_row.get("label_name")
        if pd.isna(ln) or not ln:
            continue

        cid = contract_map.get((sn, ln))
        if not cid:
            continue

        # Performer split
        bene_id = bene_map.get(sn)
        if bene_id:
            splits.append({
                "contract_id": cid,
                "isrc": isrc,
                "beneficiary_id": bene_id,
                "share_percentage": DEFAULT_SPLITS.get("performer", 0.50),
                "role": "performer",
            })

        # Label split
        label_bene_id = label_bene_map.get(ln)
        if label_bene_id:
            splits.append({
                "contract_id": cid,
                "isrc": isrc,
                "beneficiary_id": label_bene_id,
                "share_percentage": DEFAULT_SPLITS.get("composer", 0.30),
                "role": "publisher",
            })

    print(f"  Generated {len(splits)} contract_splits")

    # ── Validate BR-01 ─────────────────────────────────────────────────────
    df_splits = pd.DataFrame(splits)
    if not df_splits.empty:
        grouped = df_splits.groupby(["contract_id", "isrc"])["share_percentage"].sum()
        violations = grouped[grouped > 1.0]
        if len(violations) > 0:
            print(f"  ⚠ {len(violations)} pairs exceed 1.0 — capping")
            for idx in violations.index:
                mask = (df_splits["contract_id"] == idx[0]) & (df_splits["isrc"] == idx[1])
                total = df_splits.loc[mask, "share_percentage"].sum()
                df_splits.loc[mask, "share_percentage"] *= 1.0 / total

    # ── Persist ─────────────────────────────────────────────────────────────
    pd.DataFrame(contracts).to_csv(CLEAN_DIR / "contracts.csv", index=False)
    pd.DataFrame(beneficiaries).to_csv(CLEAN_DIR / "beneficiaries.csv", index=False)
    df_splits.to_csv(CLEAN_DIR / "contract_splits.csv", index=False)
    print("═══ Contracts transform complete ═══\n")


if __name__ == "__main__":
    run()
