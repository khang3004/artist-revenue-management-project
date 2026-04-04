"""
Load Step 6: Load Contracts, Beneficiaries, and Contract Splits
1. UPSERT contracts (UUID PK from transform).
2. UPSERT recording_contracts ISA sub-type.
3. UPSERT beneficiaries + artist_beneficiaries / label_beneficiaries.
4. UPSERT contract_splits.
"""

import pandas as pd
from sqlalchemy import text
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config import CLEAN_DIR
from load.loader import get_engine, execute_sql


def run():
    print("═══ Load: Contracts ═══")

    c_path = CLEAN_DIR / "contracts.csv"
    b_path = CLEAN_DIR / "beneficiaries.csv"
    s_path = CLEAN_DIR / "contract_splits.csv"
    for p in [c_path, b_path, s_path]:
        if not p.exists():
            print(f"  ⚠ {p.name} not found")
            return

    engine = get_engine()

    # ── Build lookup maps ───────────────────────────────────────────────────
    with engine.connect() as conn:
        rows = conn.execute(text("SELECT artist_id, stage_name FROM artists")).fetchall()
    artist_name_map = {r[1]: r[0] for r in rows}

    with engine.connect() as conn:
        rows = conn.execute(text("SELECT label_id, name FROM labels")).fetchall()
    label_name_map = {r[1]: r[0] for r in rows}

    with engine.connect() as conn:
        rows = conn.execute(text("SELECT track_id, isrc FROM tracks")).fetchall()
    isrc_map = {r[1]: r[0] for r in rows}

    # ── Contracts ───────────────────────────────────────────────────────────
    df_contracts = pd.read_csv(c_path)
    with engine.begin() as conn:
        for _, r in df_contracts.iterrows():
            conn.execute(
                text("""
                    INSERT INTO contracts (contract_id, name, start_date, end_date, contract_type, status)
                    VALUES (:contract_id, :name, :start_date, :end_date, :contract_type, :status)
                    ON CONFLICT (contract_id) DO UPDATE
                        SET name = EXCLUDED.name, status = EXCLUDED.status
                """),
                {
                    "contract_id": r["contract_id"],
                    "name": r["name"],
                    "start_date": r.get("start_date"),
                    "end_date": r.get("end_date") if pd.notna(r.get("end_date")) else None,
                    "contract_type": r.get("contract_type", "recording"),
                    "status": r.get("status", "active"),
                },
            )

            # ISA sub-type
            ctype = r.get("contract_type")
            if ctype == "recording":
                conn.execute(
                    text("""
                        INSERT INTO recording_contracts (contract_id, advance_amount, album_commitment_quantity, exclusivity_years)
                        VALUES (:cid, :adv, :qty, :yrs)
                        ON CONFLICT (contract_id) DO NOTHING
                    """),
                    {
                        "cid": r["contract_id"],
                        "adv": r.get("advance_amount"),
                        "qty": r.get("album_commitment_quantity"),
                        "yrs": r.get("exclusivity_years")
                    },
                )
            elif ctype == "distribution":
                conn.execute(
                    text("""
                        INSERT INTO distribution_contracts (contract_id, territory, distribution_fee_pct)
                        VALUES (:cid, :ter, :fee)
                        ON CONFLICT (contract_id) DO NOTHING
                    """),
                    {
                        "cid": r["contract_id"],
                        "ter": r.get("territory", "Global"),
                        "fee": float(r.get("distribution_fee_pct", 0.15))
                    },
                )
            elif ctype == "publishing":
                conn.execute(
                    text("""
                        INSERT INTO publishing_contracts (contract_id, copyright_owner, sync_rights_included)
                        VALUES (:cid, :own, :sync)
                        ON CONFLICT (contract_id) DO NOTHING
                    """),
                    {
                        "cid": r["contract_id"],
                        "own": r.get("copyright_owner", "Unknown"),
                        "sync": bool(r.get("sync_rights_included", False))
                    },
                )
    print(f"  Upserted {len(df_contracts)} contracts")

    # ── Beneficiaries ───────────────────────────────────────────────────────
    df_bene = pd.read_csv(b_path)
    bene_id_remap = {}  # old CSV id → new DB id

    # Chunk beneficiary inserts to avoid Neon connection timeouts
    CHUNK = 50
    bene_rows = list(df_bene.iterrows())
    for chunk_start in range(0, len(bene_rows), CHUNK):
        chunk = bene_rows[chunk_start: chunk_start + CHUNK]
        with engine.begin() as conn:
            for _, r in chunk:
                old_id = int(r["beneficiary_id"])
                btype = r["beneficiary_type"]

                result = conn.execute(
                    text("""
                        INSERT INTO beneficiaries (beneficiary_type)
                        VALUES (:btype)
                        RETURNING beneficiary_id
                    """),
                    {"btype": btype},
                )
                new_id = result.fetchone()[0]
                bene_id_remap[old_id] = new_id

                if btype == "A":
                    sn = r.get("artist_stage_name")
                    aid = artist_name_map.get(sn)
                    if aid:
                        conn.execute(
                            text("""
                                INSERT INTO artist_beneficiaries (beneficiary_id, artist_id)
                                VALUES (:bid, :aid)
                                ON CONFLICT (beneficiary_id) DO NOTHING
                            """),
                            {"bid": new_id, "aid": aid},
                        )
                elif btype == "L":
                    ln = r.get("label_name")
                    lid = label_name_map.get(ln)
                    if lid:
                        conn.execute(
                            text("""
                                INSERT INTO label_beneficiaries (beneficiary_id, label_id)
                                VALUES (:bid, :lid)
                                ON CONFLICT (beneficiary_id) DO NOTHING
                            """),
                            {"bid": new_id, "lid": lid},
                        )

    print(f"  Inserted {len(df_bene)} beneficiaries")

    # ── Contract Splits ─────────────────────────────────────────────────────
    df_splits = pd.read_csv(s_path)
    split_count = 0
    split_rows = list(df_splits.iterrows())
    for chunk_start in range(0, len(split_rows), CHUNK):
        chunk = split_rows[chunk_start: chunk_start + CHUNK]
        with engine.begin() as conn:
            for _, r in chunk:
                isrc = r.get("isrc")
                tid = isrc_map.get(isrc)
                if tid is None:
                    continue

                old_bene_id = int(r["beneficiary_id"])
                new_bene_id = bene_id_remap.get(old_bene_id)
                if new_bene_id is None:
                    continue

                conn.execute(
                    text("""
                        INSERT INTO contract_splits
                            (contract_id, track_id, beneficiary_id, share_percentage, role)
                        VALUES (:cid, :tid, :bid, :pct, :role)
                        ON CONFLICT (contract_id, track_id, beneficiary_id)
                        DO UPDATE SET share_percentage = EXCLUDED.share_percentage
                    """),
                    {
                        "cid": r["contract_id"],
                        "tid": tid,
                        "bid": new_bene_id,
                        "pct": float(r["share_percentage"]),
                        "role": r.get("role", "performer"),
                    },
                )
                split_count += 1

    print(f"  Upserted {split_count} contract_splits")
    print("═══ Contracts load complete ═══\n")


if __name__ == "__main__":
    run()
