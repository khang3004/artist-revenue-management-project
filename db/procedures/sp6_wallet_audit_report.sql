-- ============================================================
-- SP6: ĐỐI SOÁT WALLET VS DOANH THU THỰC (Multi-subquery + JSONB)
-- Synced from: ALL_STORED_PROCEDURES.md
-- ============================================================
CREATE OR REPLACE FUNCTION sp_wallet_audit_report()
RETURNS TABLE (
    nghe_si VARCHAR, label_name VARCHAR, genre TEXT,
    wallet_balance NUMERIC, total_earned NUMERIC, total_withdrawn NUMERIC,
    pending_withdrawal NUMERIC, chenh_lech NUMERIC, trang_thai VARCHAR
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.stage_name::VARCHAR, l.name::VARCHAR,
        (a.metadata ->> 'genre')::TEXT,
        w.balance,
        (SELECT COALESCE(SUM(r.amount * cs.share_percentage), 0)
         FROM contract_splits cs
         JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
         JOIN revenue_logs r ON cs.track_id = r.track_id
         WHERE ab.artist_id = a.artist_id),
        (SELECT COALESCE(SUM(wd.amount), 0) FROM withdrawals wd
         WHERE wd.artist_id = a.artist_id AND wd.status = 'COMPLETED'),
        (SELECT COALESCE(SUM(wd.amount), 0) FROM withdrawals wd
         WHERE wd.artist_id = a.artist_id AND wd.status = 'PENDING'),
        (SELECT COALESCE(SUM(r.amount * cs.share_percentage), 0)
         FROM contract_splits cs
         JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
         JOIN revenue_logs r ON cs.track_id = r.track_id
         WHERE ab.artist_id = a.artist_id)
        - (SELECT COALESCE(SUM(wd.amount), 0) FROM withdrawals wd
           WHERE wd.artist_id = a.artist_id AND wd.status = 'COMPLETED')
        - w.balance,
        CASE WHEN ABS(
            (SELECT COALESCE(SUM(r.amount * cs.share_percentage), 0)
             FROM contract_splits cs JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
             JOIN revenue_logs r ON cs.track_id = r.track_id WHERE ab.artist_id = a.artist_id)
            - (SELECT COALESCE(SUM(wd.amount), 0) FROM withdrawals wd
               WHERE wd.artist_id = a.artist_id AND wd.status = 'COMPLETED')
            - w.balance
        ) < 0.01 THEN 'OK' ELSE 'CẢNH BÁO' END::VARCHAR
    FROM artists a
    JOIN artist_wallets w ON a.artist_id = w.artist_id
    LEFT JOIN labels l ON a.label_id = l.label_id
    ORDER BY chenh_lech DESC;
END; $$;

-- Sample call:
-- SELECT * FROM sp_wallet_audit_report();
