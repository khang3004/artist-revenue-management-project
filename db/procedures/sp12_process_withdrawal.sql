-- ============================================================
-- SP12: XỬ LÝ WITHDRAWAL (OLTP State Machine)
--       pending → approved → completed  (hoặc rejected).
--       Balance chỉ trừ khi complete (BR-02).
-- Synced from: ALL_STORED_PROCEDURES.md
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_process_withdrawal(
    p_withdrawal_id INT,
    p_action        VARCHAR  -- 'approve' | 'reject' | 'complete'
) LANGUAGE plpgsql AS $$
DECLARE
    v_status   VARCHAR;
    v_artist   INT;
    v_amount   NUMERIC;
BEGIN
    -- Lock withdrawal row
    SELECT status, artist_id, amount INTO v_status, v_artist, v_amount
    FROM withdrawals
    WHERE withdrawal_id = p_withdrawal_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Withdrawal #% not found', p_withdrawal_id;
    END IF;

    -- State machine transitions
    CASE p_action
        WHEN 'approve' THEN
            IF v_status != 'PENDING' THEN
                RAISE EXCEPTION 'Can only approve PENDING withdrawals (current: %)', v_status;
            END IF;
            UPDATE withdrawals SET status = 'APPROVED', processed_at = NOW()
            WHERE withdrawal_id = p_withdrawal_id;

        WHEN 'reject' THEN
            IF v_status NOT IN ('PENDING', 'APPROVED') THEN
                RAISE EXCEPTION 'Cannot reject withdrawal in status %', v_status;
            END IF;
            UPDATE withdrawals SET status = 'REJECTED', processed_at = NOW()
            WHERE withdrawal_id = p_withdrawal_id;

        WHEN 'complete' THEN
            IF v_status != 'APPROVED' THEN
                RAISE EXCEPTION 'Must approve before complete (current: %)', v_status;
            END IF;
            -- BR-02: Deduct balance ONLY when completed
            UPDATE artist_wallets SET balance = balance - v_amount
            WHERE artist_id = v_artist;
            -- CHECK (balance >= 0) will throw if insufficient
            UPDATE withdrawals SET status = 'COMPLETED', processed_at = NOW()
            WHERE withdrawal_id = p_withdrawal_id;

        ELSE
            RAISE EXCEPTION 'Invalid action: "%". Expected: approve | reject | complete', p_action;
    END CASE;

    RAISE NOTICE 'Withdrawal #% → %', p_withdrawal_id, p_action;
END $$;

-- Sample calls:
-- CALL sp_process_withdrawal(1, 'approve');
-- CALL sp_process_withdrawal(1, 'complete');
-- CALL sp_process_withdrawal(2, 'reject');
