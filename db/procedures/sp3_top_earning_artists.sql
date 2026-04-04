-- ============================================================
-- MDL018 — HỆ THỐNG QUẢN LÝ DOANH THU NGHỆ SĨ V-POP
-- SP3: TOP NGHỆ SĨ DOANH THU CAO NHẤT (Subquery lồng trong HAVING)
-- ============================================================
-- Tận dụng:
--   • idx_revlog_track_date (Composite) cho aggregate
--   • Subquery lồng 2 tầng trong HAVING
--   • Partition pruning trên revenue_logs
-- ============================================================
CREATE OR REPLACE FUNCTION sp_top_earning_artists(
    p_year INT DEFAULT 2024
)
RETURNS TABLE (
    ma_nghe_si   INT,
    nghe_si      VARCHAR,
    ten_that     VARCHAR,
    label_name   VARCHAR,
    tong_doanhthu NUMERIC,
    so_tracks    BIGINT,
    so_albums    BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.artist_id,
        a.stage_name::VARCHAR,
        a.full_name::VARCHAR,
        l.name::VARCHAR,
        SUM(r.amount)                           AS tong_doanhthu,
        COUNT(DISTINCT t.track_id)              AS so_tracks,
        COUNT(DISTINCT al.album_id)             AS so_albums
    FROM artists a
    LEFT JOIN labels l    ON a.label_id = l.label_id
    JOIN albums al        ON a.artist_id = al.artist_id
    JOIN tracks t         ON al.album_id = t.album_id
    -- idx_revlog_track (B-Tree) + Partition pruning
    JOIN revenue_logs r   ON t.track_id = r.track_id
    WHERE r.log_date >= make_date(p_year, 1, 1)
      AND r.log_date < make_date(p_year + 1, 1, 1)
    GROUP BY a.artist_id, a.stage_name, a.full_name, l.name

    -- ★ SUBQUERY LỒNG 2 TẦNG TRONG HAVING ★
    -- Tìm nghệ sĩ có doanh thu = MAX doanh thu trong hệ thống
    HAVING SUM(r.amount) >= (
        -- Tầng 1: Tìm MAX tổng doanh thu
        SELECT MAX(sub_total) FROM (
            -- Tầng 2: Tính tổng doanh thu từng nghệ sĩ
            SELECT SUM(r2.amount) AS sub_total
            FROM revenue_logs r2
            JOIN tracks t2    ON r2.track_id = t2.track_id
            JOIN albums al2   ON t2.album_id = al2.album_id
            WHERE r2.log_date >= make_date(p_year, 1, 1)
              AND r2.log_date < make_date(p_year + 1, 1, 1)
            GROUP BY al2.artist_id
        ) AS artist_totals
    )
    ORDER BY tong_doanhthu DESC;
END; $$;

-- Gọi:
-- SELECT * FROM sp_top_earning_artists(2024);
