"""
Load Step 7: Populate artist_wallets and synthetic withdrawals.

Computes each artist's earned revenue from contract_splits × revenue_logs,
then generates realistic withdrawals so sp_wallet_audit_report() returns
consistent (chenh_lech ≈ 0) and interesting data.

Idempotent: clears existing wallets/withdrawals before repopulating.
"""

import random
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from load.loader import get_engine
from sqlalchemy import text

# Fixed seed → stable withdrawal amounts across re-runs
_RNG = random.Random(2025)

_METHODS = ["bank_transfer", "paypal", "e_wallet"]


def run():
    print("═══ Load: Wallets & Withdrawals ═══")

    engine = get_engine()

    # ── Compute earned per artist via contract_splits × revenue_logs ──────────
    with engine.connect() as conn:
        earned_rows = conn.execute(text("""
            SELECT
                ab.artist_id,
                COALESCE(SUM(r.amount * cs.share_percentage), 0) AS earned
            FROM contract_splits cs
            JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
            JOIN revenue_logs r          ON cs.track_id        = r.track_id
            GROUP BY ab.artist_id
        """)).fetchall()

    if not earned_rows:
        print("  ⚠ No earned data — ensure contracts/revenue_logs are loaded first")
        return

    # ── Clear previous ETL-generated wallets and withdrawals (idempotent) ─────
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM withdrawals"))
        conn.execute(text("DELETE FROM artist_wallets"))

    # ── Build wallets and withdrawals ─────────────────────────────────────────
    wallet_rows = []
    withdrawal_rows = []

    for artist_id, earned in earned_rows:
        earned = float(earned)

        completed_amount = 0.0

        # ~55% of artists have made at least one completed withdrawal
        if _RNG.random() < 0.55 and earned > 50:
            completed_amount = round(earned * _RNG.uniform(0.20, 0.45), 2)
            withdrawal_rows.append({
                "artist_id": artist_id,
                "amount": completed_amount,
                "status": "COMPLETED",
                "method": _RNG.choice(_METHODS),
            })

        # ~30% additionally have a pending withdrawal
        if _RNG.random() < 0.30 and earned > 30:
            pending_amount = round(earned * _RNG.uniform(0.05, 0.15), 2)
            withdrawal_rows.append({
                "artist_id": artist_id,
                "amount": pending_amount,
                "status": "PENDING",
                "method": _RNG.choice(_METHODS),
            })

        # balance = earned – completed (pending does NOT debit wallet)
        balance = round(max(earned - completed_amount, 0.0), 2)
        wallet_rows.append({"artist_id": artist_id, "balance": balance})

    # ── Insert wallets ────────────────────────────────────────────────────────
    with engine.begin() as conn:
        for w in wallet_rows:
            conn.execute(text("""
                INSERT INTO artist_wallets (artist_id, balance)
                VALUES (:artist_id, :balance)
                ON CONFLICT (artist_id) DO UPDATE SET balance = EXCLUDED.balance
            """), w)
    print(f"  Upserted {len(wallet_rows)} artist_wallets")

    # ── Insert withdrawals ────────────────────────────────────────────────────
    with engine.begin() as conn:
        for wd in withdrawal_rows:
            conn.execute(text("""
                INSERT INTO withdrawals (artist_id, amount, status, method)
                VALUES (:artist_id, :amount, :status, :method)
            """), wd)
    print(f"  Inserted {len(withdrawal_rows)} withdrawals "
          f"({sum(1 for w in withdrawal_rows if w['status']=='COMPLETED')} completed, "
          f"{sum(1 for w in withdrawal_rows if w['status']=='PENDING')} pending)")

    print("═══ Wallets & Withdrawals load complete ═══\n")


if __name__ == "__main__":
    run()
