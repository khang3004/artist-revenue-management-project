-- ============================================================
-- SP14: SOFT-ARCHIVE NGHỆ SĨ (OLTP)
--       Pre-condition validation, BR-04 enforcement
--       (terminate active contracts), JSONB soft-delete marker.
-- Synced from: ALL_STORED_PROCEDURES.md
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_archive_artist(
    p_artist_id INT,
    p_reason    TEXT DEFAULT NULL
) LANGUAGE plpgsql AS $$
DECLARE
    v_balance  NUMERIC;
    v_pending  INT;
    v_name     VARCHAR;
BEGIN
    -- Get artist name for logging
    SELECT stage_name INTO v_name FROM artists WHERE artist_id = p_artist_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Artist % not found', p_artist_id;
    END IF;

    -- Pre-condition 1: No pending/approved withdrawals
    SELECT COUNT(*) INTO v_pending
    FROM withdrawals
    WHERE artist_id = p_artist_id AND status IN ('pending', 'approved');

    IF v_pending > 0 THEN
        RAISE EXCEPTION 'Cannot archive "%": % pending/approved withdrawal(s). Process them first.',
            v_name, v_pending;
    END IF;

    -- Pre-condition 2: Wallet balance = 0
    SELECT balance INTO v_balance FROM artist_wallets WHERE artist_id = p_artist_id;
    IF v_balance IS NOT NULL AND v_balance > 0 THEN
        RAISE EXCEPTION 'Cannot archive "%": wallet still has balance %. Withdraw first.',
            v_name, v_balance;
    END IF;

    -- BR-04: Terminate all active contracts linked to this artist
    UPDATE contracts c SET status = 'terminated'
    WHERE c.status = 'active'
      AND EXISTS (
          SELECT 1 FROM contract_splits cs
          JOIN artist_beneficiaries ab ON cs.beneficiary_id = ab.beneficiary_id
          WHERE cs.contract_id = c.contract_id AND ab.artist_id = p_artist_id
      );

    -- Soft-delete: mark metadata (no hard DELETE — preserve audit trail)
    UPDATE artists
    SET metadata = metadata || jsonb_build_object(
            'archived', true,
            'archived_at', to_char(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
            'archived_reason', p_reason
        ),
        updated_at = NOW()
    WHERE artist_id = p_artist_id;

    RAISE NOTICE 'Artist "%" (id=%) archived. Reason: %', v_name, p_artist_id, COALESCE(p_reason, 'N/A');
END $$;

-- Sample call:
-- CALL sp_archive_artist(99, 'Nghệ sĩ ngừng hoạt động');
