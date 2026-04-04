-- ============================================================
-- MDL018 — HỆ THỐNG QUẢN LÝ DOANH THU NGHỆ SĨ V-POP
-- SP6: ĐỐI SOÁT WALLET VS DOANH THU THỰC (Multi-subquery + JSONB)
-- ============================================================
-- Tận dụng:
--   • artist_wallets 1:1 artists
--   • Subquery tính tổng doanh thu thực nhận (từ contract_splits)
--   • Subquery tính tổng đã rút (withdrawals completed)
--   • idx_withdraw_artist (B-Tree) + idx_withdraw_status (Partial: pending)
--   • JSONB query trên artists.metadata (GIN index)
-- ============================================================
CREATE OR REPLACE FUNCTION sp_wallet_audit_report()
RETURNS TABLE (
    nghe_si        VARCHAR,
    label_name     VARCHAR,
    genre          TEXT,
    wallet_balance NUMERIC,
    total_earned   NUMERIC,
    total_withdrawn NUMERIC,
    pending_withdrawal NUMERIC,
    chenh_lech     NUMERIC,
    trang_thai     VARCHAR
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.stage_name::VARCHAR,
        l.name::VARCHAR,
        -- GIN index (idx_artists_metadata_gin) hỗ trợ JSONB extract
        (a.metadata ->> 'genre')::TEXT                       AS genre,
        w.balance                                             AS wallet_balance,

        -- Subquery 1: Tổng doanh thu thực nhận từ contract splits
        -- Resolve artist via beneficiaries ISA table (V3 schema)
        (
            SELECT COALESCE(SUM(r.amount * cs.share_percentage), 0)
            FROM contract_splits cs
            JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
            JOIN revenue_logs r ON cs.track_id = r.track_id
            WHERE ab.artist_id = a.artist_id
        )                                                     AS total_earned,

        -- Subquery 2: Tổng đã rút thành công
        -- idx_withdraw_artist (B-Tree)
        (
            SELECT COALESCE(SUM(wd.amount), 0)
            FROM withdrawals wd
            WHERE wd.artist_id = a.artist_id
              AND wd.status = 'COMPLETED'
        )                                                     AS total_withdrawn,

        -- Subquery 3: Tổng đang chờ rút
        -- idx_withdraw_pending (Partial: status='PENDING')
        (
            SELECT COALESCE(SUM(wd.amount), 0)
            FROM withdrawals wd
            WHERE wd.artist_id = a.artist_id
              AND wd.status = 'PENDING'
        )                                                     AS pending_withdrawal,

        -- Chênh lệch: earned - withdrawn - balance (phải = 0 nếu đúng)
        (
            SELECT COALESCE(SUM(r.amount * cs.share_percentage), 0)
            FROM contract_splits cs
            JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
            JOIN revenue_logs r ON cs.track_id = r.track_id
            WHERE ab.artist_id = a.artist_id
        ) - (
            SELECT COALESCE(SUM(wd.amount), 0)
            FROM withdrawals wd
            WHERE wd.artist_id = a.artist_id
              AND wd.status = 'COMPLETED'
        ) - w.balance                                         AS chenh_lech,

        -- Đánh giá trạng thái audit
        CASE
            WHEN ABS(
                (SELECT COALESCE(SUM(r.amount * cs.share_percentage), 0)
                 FROM contract_splits cs
                 JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
                 JOIN revenue_logs r ON cs.track_id = r.track_id
                 WHERE ab.artist_id = a.artist_id)
                - (SELECT COALESCE(SUM(wd.amount), 0)
                   FROM withdrawals wd
                   WHERE wd.artist_id = a.artist_id AND wd.status = 'COMPLETED')
                - w.balance
            ) < 0.01 THEN 'OK'
            ELSE 'CẢNH BÁO'
        END::VARCHAR                                          AS trang_thai
    FROM artists a
    JOIN artist_wallets w ON a.artist_id = w.artist_id
    LEFT JOIN labels l    ON a.label_id = l.label_id
    ORDER BY chenh_lech DESC;
END; $$;

-- Gọi:
-- SELECT * FROM sp_wallet_audit_report();
