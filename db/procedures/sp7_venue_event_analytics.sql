-- ============================================================
-- SP7: THỐNG KÊ SỰ KIỆN & DOANH THU LIVE THEO VENUE
--      (CTE + ROLLUP + DENSE_RANK Window)
-- Synced from: ALL_STORED_PROCEDURES.md
-- ============================================================
CREATE OR REPLACE FUNCTION sp_venue_event_analytics(
    p_year INT DEFAULT 2024
)
RETURNS TABLE (
    venue_name VARCHAR, nghe_si VARCHAR, so_su_kien BIGINT,
    tong_ve_ban BIGINT, doanh_thu_live NUMERIC,
    avg_ve_per_event NUMERIC, xep_hang_venue BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH event_stats AS (
        SELECT v.venue_name, a.stage_name, e.event_id,
            (SELECT COALESCE(SUM(lrd.ticket_sold), 0) FROM live_revenue_details lrd WHERE lrd.event_id = e.event_id) AS tickets,
            (SELECT COALESCE(SUM(r.amount), 0) FROM live_revenue_details lrd JOIN revenue_logs r ON r.log_id = lrd.log_id WHERE lrd.event_id = e.event_id) AS rev
        FROM events e
        JOIN venues v            ON e.venue_id  = v.venue_id
        JOIN event_performers ep ON ep.event_id = e.event_id
        JOIN artists a           ON a.artist_id = ep.artist_id
        WHERE EXTRACT(YEAR FROM e.event_date) = p_year
          AND e.status IN ('COMPLETED', 'SCHEDULED')
    )
    SELECT
        COALESCE(es.venue_name, '★ TỔNG CỘNG ★')::VARCHAR,
        COALESCE(es.stage_name, '— Tất cả —')::VARCHAR,
        COUNT(DISTINCT es.event_id),
        SUM(es.tickets)::BIGINT,
        SUM(es.rev),
        ROUND(SUM(es.tickets)::NUMERIC / NULLIF(COUNT(DISTINCT es.event_id), 0), 0),
        DENSE_RANK() OVER (ORDER BY SUM(es.rev) DESC)
    FROM event_stats es
    GROUP BY ROLLUP(es.venue_name, es.stage_name)
    ORDER BY es.venue_name NULLS LAST, es.stage_name NULLS LAST;
END; $$;

-- Sample call:
-- SELECT * FROM sp_venue_event_analytics(2024);
