-- ============================================================
-- MDL018 — HỆ THỐNG QUẢN LÝ DOANH THU NGHỆ SĨ V-POP
-- SP2: PIVOT DOANH THU THEO NGUỒN × NGHỆ SĨ (crosstab)
-- ============================================================
-- Tận dụng:
--   • Partition pruning trên revenue_logs
--   • ISA tables: streaming_revenue_details, sync_revenue_details, live_revenue_details
--     xác định source_type (disjoint, total)
--   • idx_revlog_track_date (Composite) cho JOIN + filter
-- ============================================================
CREATE EXTENSION IF NOT EXISTS tablefunc;

CREATE OR REPLACE FUNCTION sp_revenue_pivot_by_source(
    p_year INT DEFAULT 2024
)
RETURNS TABLE (
    nghe_si    VARCHAR,
    streaming  NUMERIC,
    sync       NUMERIC,
    live       NUMERIC,
    tong       NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH revenue_typed AS (
        -- CTE xác định source_type từ ISA tables
        -- Mỗi log_id chỉ xuất hiện ở đúng 1 bảng con (disjoint, total)
        SELECT r.log_id, r.track_id, r.amount, r.log_date, 'streaming' AS source_type
        FROM revenue_logs r
        INNER JOIN streaming_revenue_details rs ON r.log_id = rs.log_id
        WHERE r.log_date >= make_date(p_year, 1, 1)
          AND r.log_date < make_date(p_year + 1, 1, 1)

        UNION ALL

        SELECT r.log_id, r.track_id, r.amount, r.log_date, 'sync'
        FROM revenue_logs r
        INNER JOIN sync_revenue_details rsn ON r.log_id = rsn.log_id
        WHERE r.log_date >= make_date(p_year, 1, 1)
          AND r.log_date < make_date(p_year + 1, 1, 1)

        UNION ALL

        SELECT r.log_id, r.track_id, r.amount, r.log_date, 'live'
        FROM revenue_logs r
        INNER JOIN live_revenue_details rl ON r.log_id = rl.log_id
        WHERE r.log_date >= make_date(p_year, 1, 1)
          AND r.log_date < make_date(p_year + 1, 1, 1)
    )
    SELECT
        ct.nghe_si,
        COALESCE(ct.streaming, 0),
        COALESCE(ct.sync, 0),
        COALESCE(ct.live, 0),
        COALESCE(ct.streaming, 0) + COALESCE(ct.sync, 0) + COALESCE(ct.live, 0) AS tong
    FROM crosstab(
        format(
            'SELECT a.stage_name::VARCHAR, rt.source_type::VARCHAR, SUM(rt.amount)::NUMERIC
             FROM (%s) rt
             LEFT JOIN tracks t ON rt.track_id = t.track_id
             LEFT JOIN albums al ON t.album_id = al.album_id
             LEFT JOIN artists a ON al.artist_id = a.artist_id
             GROUP BY a.stage_name, rt.source_type
             ORDER BY a.stage_name, rt.source_type',
            'SELECT log_id, track_id, amount, log_date, source_type FROM revenue_typed'
        ),
        $q$SELECT unnest(ARRAY['live', 'streaming', 'sync'])$q$
    ) AS ct(nghe_si VARCHAR, live NUMERIC, streaming NUMERIC, sync NUMERIC)
    ORDER BY tong DESC;
END; $$;

-- NOTE: crosstab + CTE có thể gặp khó khăn.
-- Alternative đơn giản hơn dùng conditional aggregation:

CREATE OR REPLACE FUNCTION sp_revenue_pivot_by_source_v2(
    p_year INT DEFAULT 2024
)
RETURNS TABLE (
    nghe_si    VARCHAR,
    streaming  NUMERIC,
    sync_rev   NUMERIC,
    live_rev   NUMERIC,
    tong       NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.stage_name::VARCHAR                                              AS nghe_si,
        -- PIVOT bằng conditional aggregation (tương đương crosstab)
        SUM(r.amount) FILTER (
            WHERE EXISTS (SELECT 1 FROM streaming_revenue_details rs WHERE rs.log_id = r.log_id)
        )                                                                  AS streaming,
        SUM(r.amount) FILTER (
            WHERE EXISTS (SELECT 1 FROM sync_revenue_details rsn WHERE rsn.log_id = r.log_id)
        )                                                                  AS sync_rev,
        SUM(r.amount) FILTER (
            WHERE EXISTS (SELECT 1 FROM live_revenue_details rl WHERE rl.log_id = r.log_id)
        )                                                                  AS live_rev,
        SUM(r.amount)                                                      AS tong
    FROM revenue_logs r
    LEFT JOIN tracks t   ON r.track_id = t.track_id
    LEFT JOIN albums al  ON t.album_id = al.album_id
    LEFT JOIN artists a  ON al.artist_id = a.artist_id
    WHERE r.log_date >= make_date(p_year, 1, 1)
      AND r.log_date < make_date(p_year + 1, 1, 1)
    GROUP BY a.stage_name
    ORDER BY tong DESC;
END; $$;

-- Gọi:
-- SELECT * FROM sp_revenue_pivot_by_source_v2(2024);
