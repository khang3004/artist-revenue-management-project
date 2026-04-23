-- =============================================================================
-- V9__align_with_checklist.sql
-- Align physical schema with docs/Checklist_ThietKeVatLy_VPop.md
--
-- Addresses the remaining gaps identified in the audit:
--   1. artists.full_name                          → NOT NULL
--   2. contracts.end_date                         → NOT NULL (+ strict CHECK)
--   3. distribution_contracts.distribution_fee_pct → CHECK 0-100 (percent, not fraction)
--   4. publishing_contracts.copyright_owner       → NOT NULL
--   5. sync_revenue_details.usage_type            → CHECK IN (Phim ảnh, Quảng cáo, Game, Khác)
--   6. withdrawals.method                         → CHECK IN (bank_transfer, momo, zalopay)
--   7. revenue_logs                               → append-only (block UPDATE / DELETE)
--
-- Notes for reviewers:
--   * Pre-existing NULLs are back-filled with sentinels before the NOT NULL
--     constraint is applied. Inspect these rows after migration.
--   * distribution_fee_pct values are multiplied by 100 (fraction → percent)
--     and the column type widened from NUMERIC(5,4) to NUMERIC(5,2).
--     Any SP/view using this column as a fraction must be updated (divide by 100).
--   * contracts.end_date NULLs are filled with start_date + 5 years. This
--     reverses V8's deliberate drop of NOT NULL — confirm with product before
--     deploying to prod.
-- =============================================================================

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. artists.full_name → NOT NULL
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE artists
SET full_name = stage_name
WHERE full_name IS NULL;

ALTER TABLE artists
    ALTER COLUMN full_name SET NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. contracts.end_date → NOT NULL + strict CHECK (end_date > start_date)
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE contracts
SET end_date = (start_date + INTERVAL '5 years')::DATE
WHERE end_date IS NULL;

ALTER TABLE contracts
    ALTER COLUMN end_date SET NOT NULL;

ALTER TABLE contracts
    DROP CONSTRAINT IF EXISTS chk_contracts_dates;

ALTER TABLE contracts
    ADD CONSTRAINT chk_contracts_dates CHECK (end_date > start_date);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. distribution_contracts.distribution_fee_pct → 0-100 (percent)
--    Convert existing fraction values to percent, widen column, swap CHECK.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE distribution_contracts
    DROP CONSTRAINT IF EXISTS distribution_contracts_distribution_fee_pct_check;

ALTER TABLE distribution_contracts
    ALTER COLUMN distribution_fee_pct TYPE NUMERIC(5, 2)
    USING (CASE WHEN distribution_fee_pct <= 1 THEN distribution_fee_pct * 100 ELSE distribution_fee_pct END);

ALTER TABLE distribution_contracts
    ADD CONSTRAINT distribution_contracts_distribution_fee_pct_check
    CHECK (distribution_fee_pct >= 0 AND distribution_fee_pct <= 100);

COMMENT ON COLUMN distribution_contracts.distribution_fee_pct IS
    'Distributor fee as a PERCENT of revenue (0-100). Previously stored as fraction 0-1 in V3; converted in V9.';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. publishing_contracts.copyright_owner → NOT NULL
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE publishing_contracts
SET copyright_owner = 'UNKNOWN'
WHERE copyright_owner IS NULL;

ALTER TABLE publishing_contracts
    ALTER COLUMN copyright_owner SET NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. sync_revenue_details.usage_type → CHECK IN (Phim ảnh, Quảng cáo, Game, Khác)
--    Non-matching values are coerced to 'Khác' before the constraint is added.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE sync_revenue_details
SET usage_type = 'Khác'
WHERE usage_type NOT IN ('Phim ảnh', 'Quảng cáo', 'Game', 'Khác');

ALTER TABLE sync_revenue_details
    DROP CONSTRAINT IF EXISTS sync_revenue_details_usage_type_check;

ALTER TABLE sync_revenue_details
    ADD CONSTRAINT sync_revenue_details_usage_type_check
    CHECK (usage_type IN ('Phim ảnh', 'Quảng cáo', 'Game', 'Khác'));

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. withdrawals.method → CHECK IN (bank_transfer, momo, zalopay). NULL allowed.
--    Unknown non-NULL values are reset to NULL.
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE withdrawals
SET method = NULL
WHERE method IS NOT NULL
  AND method NOT IN ('bank_transfer', 'momo', 'zalopay');

ALTER TABLE withdrawals
    DROP CONSTRAINT IF EXISTS withdrawals_method_check;

ALTER TABLE withdrawals
    ADD CONSTRAINT withdrawals_method_check
    CHECK (method IS NULL OR method IN ('bank_transfer', 'momo', 'zalopay'));

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. revenue_logs → append-only: block UPDATE and DELETE at the row level.
--    INSERT remains allowed (ETL / BR-03 trigger chain).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION fn_revenue_logs_append_only()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION
        '[APPEND-ONLY] revenue_logs does not permit % (log_id=%).',
        TG_OP, COALESCE(OLD.log_id, NEW.log_id);
END;
$$;

COMMENT ON FUNCTION fn_revenue_logs_append_only() IS
    'Enforces the append-only policy on revenue_logs (checklist 5.17). Blocks UPDATE and DELETE; INSERT is allowed.';

DROP TRIGGER IF EXISTS trg_revenue_logs_no_update ON revenue_logs;
CREATE TRIGGER trg_revenue_logs_no_update
BEFORE UPDATE ON revenue_logs
FOR EACH ROW EXECUTE FUNCTION fn_revenue_logs_append_only();

DROP TRIGGER IF EXISTS trg_revenue_logs_no_delete ON revenue_logs;
CREATE TRIGGER trg_revenue_logs_no_delete
BEFORE DELETE ON revenue_logs
FOR EACH ROW EXECUTE FUNCTION fn_revenue_logs_append_only();

COMMIT;
