-- =============================================================================
-- V10__materialized_views.sql
-- Materialized views for reporting dashboards + sp_refresh_all_mv
-- Depends on: V1 (artists, albums, tracks), V3 (contract_splits,
--             beneficiaries), V5 (revenue_logs, artist_wallets)
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- MV 1: Artist Revenue Summary
-- Aggregates total revenue per artist across all sources.
-- Used by: dashboard, sp_refresh_all_mv (CONCURRENTLY — needs unique index)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE MATERIALIZED VIEW mv_artist_revenue_summary AS
SELECT
    a.artist_id,
    a.stage_name,
    COUNT(DISTINCT t.track_id)          AS total_tracks,
    COUNT(r.log_id)                     AS total_transactions,
    COALESCE(SUM(r.amount), 0)          AS total_revenue,
    MAX(r.log_date)                     AS last_revenue_date
FROM artists a
LEFT JOIN albums al   ON a.artist_id = al.artist_id
LEFT JOIN tracks t    ON al.album_id = t.album_id
LEFT JOIN revenue_logs r ON t.track_id = r.track_id
GROUP BY a.artist_id, a.stage_name
WITH NO DATA;

CREATE UNIQUE INDEX idx_mv_artist_rev_summary_pk
    ON mv_artist_revenue_summary (artist_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- MV 2: Top Tracks Cached
-- Pre-ranked tracks by revenue for fast dashboard lookups.
-- Used by: sp_refresh_all_mv (CONCURRENTLY — needs unique index)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE MATERIALIZED VIEW mv_top_tracks_cached AS
SELECT
    t.track_id,
    t.title          AS track_title,
    t.isrc,
    t.play_count,
    al.title         AS album_title,
    a.stage_name,
    COALESCE(SUM(r.amount), 0)                                              AS total_revenue,
    RANK() OVER (ORDER BY COALESCE(SUM(r.amount), 0) DESC)                  AS revenue_rank
FROM tracks t
JOIN albums al   ON t.album_id = al.album_id
JOIN artists a   ON al.artist_id = a.artist_id
LEFT JOIN revenue_logs r ON t.track_id = r.track_id
GROUP BY t.track_id, t.title, t.isrc, t.play_count, al.title, a.stage_name
WITH NO DATA;

CREATE UNIQUE INDEX idx_mv_top_tracks_pk
    ON mv_top_tracks_cached (track_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- MV 3: Monthly Revenue by Source Type
-- Time-series aggregation for trend charts.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE MATERIALIZED VIEW mv_monthly_revenue_by_source AS
SELECT
    DATE_TRUNC('month', r.log_date)::DATE AS month,
    r.revenue_type,
    COUNT(r.log_id)                       AS log_count,
    COALESCE(SUM(r.amount), 0)            AS total_amount
FROM revenue_logs r
GROUP BY DATE_TRUNC('month', r.log_date), r.revenue_type
WITH NO DATA;

-- ─────────────────────────────────────────────────────────────────────────────
-- MV 4: Contract Split Summary
-- Denormalized view of contracts with their beneficiaries and splits.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE MATERIALIZED VIEW mv_contract_split_summary AS
SELECT
    c.contract_id,
    c.name                                      AS contract_name,
    c.contract_type,
    c.status,
    cs.track_id,
    t.title                                     AS track_title,
    cs.beneficiary_id,
    COALESCE(a.stage_name, l.name)              AS beneficiary_name,
    CASE WHEN ab.beneficiary_id IS NOT NULL THEN 'Artist' ELSE 'Label' END AS beneficiary_type,
    cs.share_percentage,
    cs.role
FROM contracts c
JOIN contract_splits cs          ON c.contract_id = cs.contract_id
JOIN tracks t                    ON cs.track_id   = t.track_id
LEFT JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
LEFT JOIN label_beneficiaries  lb ON lb.beneficiary_id = cs.beneficiary_id
LEFT JOIN artists a              ON a.artist_id = ab.artist_id
LEFT JOIN labels  l              ON l.label_id  = lb.label_id
WITH NO DATA;
