-- ============================================================
-- MDL018 — HỆ THỐNG QUẢN LÝ DOANH THU NGHỆ SĨ V-POP
-- SP8: TÌM NGHỆ SĨ THEO METADATA JSONB
-- ============================================================
-- Tận dụng:
--   • idx_artists_metadata_gin (GIN) cho @> operator
--   • idx_artists_name_lower (Expression) cho ILIKE search
-- ============================================================
CREATE OR REPLACE FUNCTION sp_search_artists(
    p_genre VARCHAR DEFAULT NULL,
    p_name  VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    artist_id    INT,
    stage_name   VARCHAR,
    full_name    VARCHAR,
    genre        TEXT,
    social_links JSONB,
    label_name   VARCHAR,
    total_tracks BIGINT,
    total_plays  BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.artist_id,
        a.stage_name::VARCHAR,
        a.full_name::VARCHAR,
        (a.metadata ->> 'genre')::TEXT,
        (a.metadata -> 'social_links')::JSONB,
        l.name::VARCHAR,
        -- Subquery đếm tracks
        (
            SELECT COUNT(*)::BIGINT
            FROM tracks t
            JOIN albums al ON t.album_id = al.album_id
            WHERE al.artist_id = a.artist_id
        ),
        -- Subquery tổng plays
        (
            SELECT COALESCE(SUM(t.play_count), 0)::BIGINT
            FROM tracks t
            JOIN albums al ON t.album_id = al.album_id
            WHERE al.artist_id = a.artist_id
        )
    FROM artists a
    LEFT JOIN labels l ON a.label_id = l.label_id
    WHERE
        -- GIN index: tìm theo genre trong JSONB
        (p_genre IS NULL OR a.metadata @> jsonb_build_object('genre', p_genre))
        -- Expression index: case-insensitive name search
        AND (p_name IS NULL OR LOWER(a.stage_name) LIKE '%' || LOWER(p_name) || '%')
    ORDER BY a.stage_name;
END; $$;

-- Gọi:
-- SELECT * FROM sp_search_artists('pop', NULL);         -- tìm theo genre
-- SELECT * FROM sp_search_artists(NULL, 'sơn tùng');    -- tìm theo tên
-- SELECT * FROM sp_search_artists('pop', 'tùng');       -- kết hợp
