-- ============================================================
-- SP5: TOP TRACKS THEO DOANH THU MỖI NGHỆ SĨ (RANK() Window)
-- Synced from: ALL_STORED_PROCEDURES.md
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
        ranked.nghe_si, ranked.track_title, ranked.album_title,
        ranked.isrc, ranked.play_count, ranked.tong_doanhthu, ranked.hang
    FROM (
        SELECT
            a.stage_name::VARCHAR AS nghe_si,
            t.title::VARCHAR AS track_title,
            al.title::VARCHAR AS album_title,
            t.isrc::VARCHAR,
            t.play_count,
            COALESCE(SUM(r.amount), 0) AS tong_doanhthu,
            RANK() OVER (PARTITION BY a.artist_id ORDER BY COALESCE(SUM(r.amount), 0) DESC) AS hang
        FROM artists a
        JOIN albums al ON a.artist_id = al.artist_id
        JOIN tracks t  ON al.album_id = t.album_id
        LEFT JOIN revenue_logs r ON t.track_id = r.track_id
            AND r.log_date >= make_date(p_year, 1, 1)
            AND r.log_date < make_date(p_year + 1, 1, 1)
        GROUP BY a.artist_id, a.stage_name, t.track_id, t.title, al.title, t.isrc, t.play_count
    ) ranked
    WHERE ranked.hang <= p_top_n
    ORDER BY ranked.nghe_si, ranked.hang;
END; $$;

-- Sample call:
-- SELECT * FROM sp_top_tracks_per_artist(5, 2024);
