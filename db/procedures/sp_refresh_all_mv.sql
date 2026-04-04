-- ============================================================
-- MDL018 — HỆ THỐNG QUẢN LÝ DOANH THU NGHỆ SĨ V-POP
-- UTILITY: REFRESH ALL MATERIALIZED VIEWS
-- ============================================================
-- Gọi sau khi INSERT dữ liệu mới hoặc schedule bằng pg_cron
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_refresh_all_mv()
LANGUAGE plpgsql AS $$
BEGIN
    -- CONCURRENTLY cho phép đọc trong khi refresh (cần UNIQUE INDEX trên MV)
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_artist_revenue_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_tracks_cached;
    REFRESH MATERIALIZED VIEW mv_monthly_revenue_by_source;
    REFRESH MATERIALIZED VIEW mv_contract_split_summary;
    RAISE NOTICE 'All materialized views refreshed at %', NOW();
END; $$;

-- Gọi:
-- CALL sp_refresh_all_mv();
