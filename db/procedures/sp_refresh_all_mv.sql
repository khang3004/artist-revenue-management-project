-- ============================================================
-- UTILITY: REFRESH ALL MATERIALIZED VIEWS
-- Schedule via pg_cron or call post-ETL.
-- Synced from: ALL_STORED_PROCEDURES.md
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_refresh_all_mv()
LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_artist_revenue_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_tracks_cached;
    REFRESH MATERIALIZED VIEW mv_monthly_revenue_by_source;
    REFRESH MATERIALIZED VIEW mv_contract_split_summary;
    RAISE NOTICE 'All materialized views refreshed at %', NOW();
END; $$;

-- Sample call:
-- CALL sp_refresh_all_mv();
