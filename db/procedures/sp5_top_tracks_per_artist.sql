-- ============================================================
-- MDL018 — HỆ THỐNG QUẢN LÝ DOANH THU NGHỆ SĨ V-POP
-- SP5: TOP TRACKS THEO DOANH THU MỖI NGHỆ SĨ (Window function + Subquery)
-- ============================================================
-- Tận dụng:
--   • idx_revlog_track_date (Composite) cho aggregate
--   • RANK() OVER (PARTITION BY ... ORDER BY ...) window function
--   • Subquery trong FROM để tạo ranked dataset
--   • idx_tracks_popular (Partial: play_count > 1M) cho filter
-- ============================================================
CREATE OR REPLACE FUNCTION sp_top_tracks_per_artist(
    p_top_n INT DEFAULT 3,
    p_year INT DEFAULT 2024
)
RETURNS TABLE (
    nghe_si       VARCHAR,
    track_title   VARCHAR,
    album_title   VARCHAR,
    isrc          VARCHAR,
    play_count    BIGINT,
    tong_doanhthu NUMERIC,
    hang          BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        ranked.nghe_si,
        ranked.track_title,
        ranked.album_title,
        ranked.isrc,
        ranked.play_count,
        ranked.tong_doanhthu,
        ranked.hang
    FROM (
        SELECT
            a.stage_name::VARCHAR                        AS nghe_si,
            t.title::VARCHAR                             AS track_title,
            al.title::VARCHAR                            AS album_title,
            t.isrc::VARCHAR                              AS isrc,
            t.play_count,
            COALESCE(SUM(r.amount), 0)                   AS tong_doanhthu,
            RANK() OVER (
                PARTITION BY a.artist_id
                ORDER BY COALESCE(SUM(r.amount), 0) DESC
            )                                            AS hang
        FROM artists a
        JOIN albums al     ON a.artist_id = al.artist_id
        JOIN tracks t      ON al.album_id = t.album_id
        -- idx_revlog_track + Partition pruning
        LEFT JOIN revenue_logs r ON t.track_id = r.track_id
            AND r.log_date >= make_date(p_year, 1, 1)
            AND r.log_date < make_date(p_year + 1, 1, 1)
        GROUP BY a.artist_id, a.stage_name, t.track_id, t.title, al.title, t.isrc, t.play_count
    ) ranked
    -- Subquery filter: chỉ lấy top N mỗi nghệ sĩ
    WHERE ranked.hang <= p_top_n
    ORDER BY ranked.nghe_si, ranked.hang;
END; $$;

-- Gọi:
-- SELECT * FROM sp_top_tracks_per_artist(5, 2024);  -- Top 5 tracks/nghệ sĩ
