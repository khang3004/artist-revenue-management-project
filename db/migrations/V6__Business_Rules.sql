-- =============================================================================
-- V6__Business_Rules.sql
-- Migration: Database-layer enforcement of business rules via triggers
-- Depends on: V3 (contract_splits), V5 (artist_wallets, withdrawals,
--             revenue_logs), V1 (tracks, artists)
--
-- Business Rules encoded:
--   BR-01  contract_splits: sum of share_percentage per (contract, track)
--          must not exceed 1.0
--   BR-02  withdrawals: artist_wallets.balance decreases ONLY when a
--          withdrawal transitions to status = 'completed'
--   BR-03  revenue_logs: artist_wallets.balance auto-credits based on
--          contract_splits whenever a revenue_log is inserted
--   BR-04  tracks: play_count can only increase (monotonic)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- BR-01  Split percentage cap
-- Prevents total share_percentage across all rows for the same
-- (contract_id, track_id) pair from exceeding 1.0 (100 %).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_check_split_percentage()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    -- Sum all splits for this contract × track pair, excluding the current row
    -- on UPDATE (split_id comparison) so we don't double-count.
    SELECT COALESCE(SUM(share_percentage), 0)
    INTO   v_total
    FROM   contract_splits
    WHERE  contract_id    = NEW.contract_id
      AND  track_id       = NEW.track_id
      AND  (TG_OP = 'INSERT' OR split_id <> NEW.split_id);

    v_total := v_total + NEW.share_percentage;

    IF v_total > 1.0 THEN
        RAISE EXCEPTION
            '[BR-01] Total share_percentage for contract % on track % would be % (max 1.0).',
            NEW.contract_id, NEW.track_id, v_total;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_split_percentage
BEFORE INSERT OR UPDATE ON contract_splits
FOR EACH ROW EXECUTE FUNCTION fn_check_split_percentage();

COMMENT ON FUNCTION fn_check_split_percentage() IS
    'BR-01: Ensures total split percentages per (contract, track) never exceed 1.0.';

-- ─────────────────────────────────────────────────────────────────────────────
-- BR-02  Wallet debits only on completed withdrawals
-- When a withdrawal row is INSERT-ed or UPDATE-d:
--   • INSERT with status='completed'  → debit artist wallet immediately.
--   • UPDATE  to  status='completed'  → debit only once (transition guard).
--   • UPDATE *away from* 'completed'  → credit back (reversal).
--   • pending / rejected              → no change to wallet.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_wallet_balance_on_withdrawal()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    -- ── INSERT path ────────────────────────────────────────────────────────
    IF TG_OP = 'INSERT' THEN
        IF NEW.status = 'COMPLETED' THEN
            -- Debit the wallet; constraint on artist_wallets.balance >= 0
            -- will fire automatically if funds are insufficient.
            UPDATE artist_wallets
            SET    balance = balance - NEW.amount
            WHERE  artist_id = NEW.artist_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION
                    '[BR-02] No wallet found for artist_id %.', NEW.artist_id;
            END IF;
        END IF;

    -- ── UPDATE path ────────────────────────────────────────────────────────
    ELSIF TG_OP = 'UPDATE' THEN
        -- Transition: non-completed → completed  (debit)
        IF OLD.status <> 'COMPLETED' AND NEW.status = 'COMPLETED' THEN
            UPDATE artist_wallets
            SET    balance = balance - NEW.amount
            WHERE  artist_id = NEW.artist_id;

            IF NOT FOUND THEN
                RAISE EXCEPTION
                    '[BR-02] No wallet found for artist_id %.', NEW.artist_id;
            END IF;

        -- Transition: completed → non-completed  (credit back / reversal)
        ELSIF OLD.status = 'COMPLETED' AND NEW.status <> 'COMPLETED' THEN
            UPDATE artist_wallets
            SET    balance = balance + OLD.amount
            WHERE  artist_id = NEW.artist_id;
        END IF;

        -- Guard: once completed, amount must not change
        IF OLD.status = 'COMPLETED' AND NEW.status = 'COMPLETED'
           AND OLD.amount IS DISTINCT FROM NEW.amount THEN
            RAISE EXCEPTION
                '[BR-02] Cannot alter amount of a completed withdrawal (id=%).',
                NEW.withdrawal_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_wallet_balance_on_withdrawal
BEFORE INSERT OR UPDATE ON withdrawals
FOR EACH ROW EXECUTE FUNCTION fn_wallet_balance_on_withdrawal();

COMMENT ON FUNCTION fn_wallet_balance_on_withdrawal() IS
    'BR-02: Debits artist_wallets.balance only when a withdrawal reaches status=''completed''.';

-- ─────────────────────────────────────────────────────────────────────────────
-- BR-03  Auto-credit wallets on new revenue log
-- When a revenue_log is inserted, look up contract_splits for the track
-- and distribute the gross amount to each beneficiary's artist wallet
-- according to share_percentage.
-- Only artist_beneficiaries receive wallet credits (label shares are
-- tracked for reporting but have no wallet in this schema).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_revenue_log_credit()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    r RECORD;
BEGIN
    -- Only credit when a track is associated with the log
    IF NEW.track_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Iterate over every split row for this track
    -- (join restricts to artist beneficiaries only)
    FOR r IN
        SELECT ab.artist_id,
               cs.share_percentage
        FROM   contract_splits      cs
        JOIN   beneficiaries        b  ON b.beneficiary_id   = cs.beneficiary_id
        JOIN   artist_beneficiaries ab ON ab.beneficiary_id  = cs.beneficiary_id
        -- Use ANY active contract that covers this track; a more refined
        -- selection (e.g. narrowed by contract date) can be added as needed.
        JOIN   contracts            c  ON c.contract_id      = cs.contract_id
                                      AND c.status           = 'active'
        WHERE  cs.track_id = NEW.track_id
          AND  b.beneficiary_type = 'A'
    LOOP
        -- Upsert: ensure the wallet row exists, then credit
        INSERT INTO artist_wallets (artist_id, balance)
        VALUES (r.artist_id, NEW.amount * r.share_percentage)
        ON CONFLICT (artist_id)
        DO UPDATE SET balance = artist_wallets.balance
                              + EXCLUDED.balance;
    END LOOP;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_revenue_log_credit
AFTER INSERT ON revenue_logs
FOR EACH ROW EXECUTE FUNCTION fn_revenue_log_credit();

COMMENT ON FUNCTION fn_revenue_log_credit() IS
    'BR-03: Auto-distributes revenue to artist wallets based on contract_splits on each INSERT into revenue_logs.';

-- ─────────────────────────────────────────────────────────────────────────────
-- BR-04  play_count is monotonically non-decreasing
-- Prevents any UPDATE from setting play_count to a lower value than the
-- current stored value.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_play_count_no_decrease()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.play_count < OLD.play_count THEN
        RAISE EXCEPTION
            '[BR-04] play_count for track_id % cannot decrease (old=%, new=%).',
            NEW.track_id, OLD.play_count, NEW.play_count;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_play_count_no_decrease
BEFORE UPDATE ON tracks
FOR EACH ROW
WHEN (NEW.play_count IS DISTINCT FROM OLD.play_count)
EXECUTE FUNCTION fn_play_count_no_decrease();

COMMENT ON FUNCTION fn_play_count_no_decrease() IS
    'BR-04: Ensures tracks.play_count can only increase (monotonic non-decreasing).';

-- ─────────────────────────────────────────────────────────────────────────────
-- BR-05  Enforce Disjoint ISA for Beneficiaries
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_enforce_artist_beneficiary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_type CHAR(1);
BEGIN
    SELECT beneficiary_type INTO v_type FROM beneficiaries WHERE beneficiary_id = NEW.beneficiary_id;
    IF v_type <> 'A' THEN RAISE EXCEPTION '[BR-05] beneficiary_id % is not an Artist (type=%).', NEW.beneficiary_id, v_type; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_enforce_artist_beneficiary BEFORE INSERT OR UPDATE ON artist_beneficiaries FOR EACH ROW EXECUTE FUNCTION fn_enforce_artist_beneficiary();

CREATE OR REPLACE FUNCTION fn_enforce_label_beneficiary()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_type CHAR(1);
BEGIN
    SELECT beneficiary_type INTO v_type FROM beneficiaries WHERE beneficiary_id = NEW.beneficiary_id;
    IF v_type <> 'L' THEN RAISE EXCEPTION '[BR-05] beneficiary_id % is not a Label (type=%).', NEW.beneficiary_id, v_type; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_enforce_label_beneficiary BEFORE INSERT OR UPDATE ON label_beneficiaries FOR EACH ROW EXECUTE FUNCTION fn_enforce_label_beneficiary();

-- ─────────────────────────────────────────────────────────────────────────────
-- BR-06  Enforce Disjoint ISA for Contracts
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_enforce_recording_contract()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_type VARCHAR;
BEGIN
    SELECT contract_type INTO v_type FROM contracts WHERE contract_id = NEW.contract_id;
    IF v_type <> 'recording' THEN RAISE EXCEPTION '[BR-06] contract_id % has type %, not recording.', NEW.contract_id, v_type; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_enforce_recording_contract BEFORE INSERT OR UPDATE ON recording_contracts FOR EACH ROW EXECUTE FUNCTION fn_enforce_recording_contract();

CREATE OR REPLACE FUNCTION fn_enforce_distribution_contract()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_type VARCHAR;
BEGIN
    SELECT contract_type INTO v_type FROM contracts WHERE contract_id = NEW.contract_id;
    IF v_type <> 'distribution' THEN RAISE EXCEPTION '[BR-06] contract_id % has type %, not distribution.', NEW.contract_id, v_type; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_enforce_distribution_contract BEFORE INSERT OR UPDATE ON distribution_contracts FOR EACH ROW EXECUTE FUNCTION fn_enforce_distribution_contract();

CREATE OR REPLACE FUNCTION fn_enforce_publishing_contract()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_type VARCHAR;
BEGIN
    SELECT contract_type INTO v_type FROM contracts WHERE contract_id = NEW.contract_id;
    IF v_type <> 'publishing' THEN RAISE EXCEPTION '[BR-06] contract_id % has type %, not publishing.', NEW.contract_id, v_type; END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_enforce_publishing_contract BEFORE INSERT OR UPDATE ON publishing_contracts FOR EACH ROW EXECUTE FUNCTION fn_enforce_publishing_contract();
