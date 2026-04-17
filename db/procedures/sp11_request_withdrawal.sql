-- ============================================================
-- SP11: YÊU CẦU RÚT TIỀN (OLTP)
--       SELECT ... FOR UPDATE (row lock), available = balance − pending,
--       BR-02 compliance (balance NOT deducted until completed).
-- Synced from: ALL_STORED_PROCEDURES.md
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_request_withdrawal(
    p_artist_id       INT,
    p_amount          NUMERIC,
    p_method          VARCHAR DEFAULT 'bank_transfer',
    p_note            TEXT DEFAULT NULL,
    OUT new_withdrawal_id INT
) LANGUAGE plpgsql AS $$
DECLARE
    v_balance       NUMERIC;
    v_pending_total NUMERIC;
    v_available     NUMERIC;
BEGIN
    -- Lock wallet row — prevent concurrent withdrawal race condition
    SELECT balance INTO v_balance
    FROM artist_wallets
    WHERE artist_id = p_artist_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Artist % has no wallet (not registered?)', p_artist_id;
    END IF;

    -- Calculate available = balance − all pending
    SELECT COALESCE(SUM(amount), 0) INTO v_pending_total
    FROM withdrawals
    WHERE artist_id = p_artist_id AND status IN ('pending', 'approved');

    v_available := v_balance - v_pending_total;

    IF p_amount > v_available THEN
        RAISE EXCEPTION 'Insufficient available balance. Balance=%, Pending=%, Available=%, Requested=%',
            v_balance, v_pending_total, v_available, p_amount;
    END IF;

    -- Insert request (status=pending, balance NOT deducted yet — BR-02)
    INSERT INTO withdrawals (artist_id, amount, status, requested_at, method, note)
    VALUES (p_artist_id, p_amount, 'pending', NOW(), p_method, p_note)
    RETURNING withdrawal_id INTO new_withdrawal_id;

    RAISE NOTICE 'Withdrawal #% requested: % % for artist %',
        new_withdrawal_id, p_amount, p_method, p_artist_id;
END $$;

-- Sample call:
-- CALL sp_request_withdrawal(1, 500000000, 'bank_transfer', 'Rút Q2', NULL);
