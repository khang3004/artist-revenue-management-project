-- ============================================================
-- MDL018 — HỆ THỐNG QUẢN LÝ DOANH THU NGHỆ SĨ V-POP
-- SP1: DOANH THU THEO NGHỆ SĨ & THÁNG (ROLLUP)
-- ============================================================
-- Tận dụng:
--   • idx_revlog_track (B-Tree) cho JOIN revenue_logs → tracks
--   • idx_revlog_month (Expression: DATE_TRUNC) cho GROUP BY tháng
--   • Partition pruning trên revenue_logs (range by log_date)
--   • idx_revlog_currency (B-Tree) cho lọc đơn vị tiền
-- ============================================================
CREATE OR REPLACE FUNCTION sp_revenue_by_artist_rollup(
    p_year INT DEFAULT 2024,
    p_currency VARCHAR DEFAULT 'VND'
)
RETURNS TABLE (
    nghe_si      VARCHAR,
    thang        TEXT,
    so_giao_dich BIGINT,
    tong_doanhthu NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(a.stage_name, '★ TỔNG CỘNG ★')::VARCHAR    AS nghe_si,
        COALESCE(
            TO_CHAR(DATE_TRUNC('month', r.log_date), 'MM/YYYY'),
            '— Tất cả —'
        )::TEXT                                                AS thang,
        COUNT(r.log_id)                                        AS so_giao_dich,
        COALESCE(SUM(r.amount), 0)                             AS tong_doanhthu
    FROM revenue_logs r
    -- idx_revlog_track (B-Tree) tăng tốc JOIN
    JOIN tracks t    ON r.track_id = t.track_id
    -- idx_tracks_album (B-Tree)
    JOIN albums al   ON t.album_id = al.album_id
    -- idx_albums_artist (B-Tree)
    JOIN artists a   ON al.artist_id = a.artist_id
    WHERE
        -- Partition pruning: chỉ quét partition của năm p_year
        r.log_date >= make_date(p_year, 1, 1)
        AND r.log_date < make_date(p_year + 1, 1, 1)
        -- idx_revlog_currency (B-Tree) lọc nhanh
        AND r.currency = p_currency
    GROUP BY ROLLUP(a.stage_name, DATE_TRUNC('month', r.log_date))
    ORDER BY
        a.stage_name NULLS LAST,
        DATE_TRUNC('month', r.log_date) NULLS LAST;
END; $$;

-- Gọi:
-- SELECT * FROM sp_revenue_by_artist_rollup(2024, 'VND');
