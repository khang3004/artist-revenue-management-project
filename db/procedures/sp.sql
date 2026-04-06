-- ============================================================
-- MDL018 — HỆ THỐNG QUẢN LÝ DOANH THU NGHỆ SĨ V-POP
-- Stored Procedures — Khai thác dữ liệu
-- PostgreSQL 16
--
-- Tận dụng: Partition pruning, B-Tree/Composite/Partial/GIN index,
--           Materialized Views, Expression index
-- Kỹ thuật: ROLLUP, crosstab (PIVOT), subquery lồng,
--           Window functions, CTE, LATERAL JOIN, JSONB operators
-- ============================================================

CREATE EXTENSION IF NOT EXISTS tablefunc;

-- ============================================================
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


-- ============================================================
-- SP2: PIVOT DOANH THU THEO NGUỒN × NGHỆ SĨ (crosstab)
-- ============================================================
-- Tận dụng:
--   • Partition pruning trên revenue_logs
--   • ISA tables: streaming_revenue_details, sync_revenue_details, live_revenue_details
--     xác định source_type (disjoint, total)
--   • idx_revlog_track_date (Composite) cho JOIN + filter
-- ============================================================
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
        $$SELECT unnest(ARRAY['live', 'streaming', 'sync'])$$
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


-- ============================================================
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


-- ============================================================
-- SP4: PHÂN CHIA DOANH THU THEO HỢP ĐỒNG (Subquery + LATERAL)
-- ============================================================
-- Tận dụng:
--   • idx_splits_contract_track (Composite) cho JOIN contract_splits
--   • idx_splits_artist, idx_splits_label (B-Tree) cho beneficiary lookup
--   • Polymorphic FK: COALESCE(artist_name, label_name)
--   • idx_contracts_active (Partial) cho lọc hợp đồng active
-- ============================================================
CREATE OR REPLACE FUNCTION sp_contract_revenue_distribution(
    p_contract_id UUID DEFAULT NULL
)
RETURNS TABLE (
    contract_name VARCHAR,
    contract_status VARCHAR,
    track_title  VARCHAR,
    beneficiary  VARCHAR,
    beneficiary_type VARCHAR,
    role         VARCHAR,
    share_pct    NUMERIC,
    track_total_revenue NUMERIC,
    actual_payout NUMERIC
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.name::VARCHAR                                      AS contract_name,
        c.status::VARCHAR                                    AS contract_status,
        t.title::VARCHAR                                     AS track_title,
        -- Polymorphic beneficiary resolution via beneficiaries table
        COALESCE(a_ben.stage_name, l_ben.name)::VARCHAR      AS beneficiary,
        CASE
            WHEN ab.beneficiary_id IS NOT NULL THEN 'Artist'
            ELSE 'Label'
        END::VARCHAR                                          AS beneficiary_type,
        cs.role::VARCHAR,
        cs.share_percentage,
        -- Subquery: tổng doanh thu cho track này
        (
            SELECT COALESCE(SUM(r.amount), 0)
            FROM revenue_logs r
            WHERE r.track_id = t.track_id
        )                                                     AS track_total_revenue,
        -- Tính actual payout = total × share%
        ROUND(
            (
                SELECT COALESCE(SUM(r.amount), 0)
                FROM revenue_logs r
                WHERE r.track_id = t.track_id
            ) * cs.share_percentage, 2
        )                                                     AS actual_payout
    FROM contracts c
    -- idx_splits_contract_track (Composite) tăng tốc
    JOIN contract_splits cs ON c.contract_id = cs.contract_id
    JOIN tracks t           ON cs.track_id = t.track_id
    -- Polymorphic FK resolution via beneficiaries ISA table
    LEFT JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
    LEFT JOIN label_beneficiaries  lb ON lb.beneficiary_id = cs.beneficiary_id
    LEFT JOIN artists a_ben ON a_ben.artist_id = ab.artist_id
    LEFT JOIN labels  l_ben ON l_ben.label_id  = lb.label_id
    WHERE
        -- idx_contracts_active (Partial) nếu không truyền contract cụ thể
        (p_contract_id IS NULL AND c.status = 'active')
        OR c.contract_id = p_contract_id
    ORDER BY c.name, actual_payout DESC;
END; $$;

-- Gọi:
-- SELECT * FROM sp_contract_revenue_distribution();                    -- tất cả active
-- SELECT * FROM sp_contract_revenue_distribution('uuid-here'::UUID);  -- 1 hợp đồng cụ thể


-- ============================================================
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


-- ============================================================
-- SP6: ĐỐI SOÁT WALLET VS DOANH THU THỰC (Multi-subquery + JSONB)
-- ============================================================
-- Tận dụng:
--   • artist_wallets 1:1 artists
--   • Subquery tính tổng doanh thu thực nhận (từ contract_splits)
--   • Subquery tính tổng đã rút (withdrawals completed)
--   • idx_withdraw_artist (B-Tree) + idx_withdraw_status (Partial: pending)
--   • JSONB query trên artists.metadata (GIN index)
-- ============================================================
CREATE OR REPLACE FUNCTION sp_wallet_audit_report()
RETURNS TABLE (
    nghe_si        VARCHAR,
    label_name     VARCHAR,
    genre          TEXT,
    wallet_balance NUMERIC,
    total_earned   NUMERIC,
    total_withdrawn NUMERIC,
    pending_withdrawal NUMERIC,
    chenh_lech     NUMERIC,
    trang_thai     VARCHAR
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.stage_name::VARCHAR,
        l.name::VARCHAR,
        -- GIN index (idx_artists_metadata_gin) hỗ trợ JSONB extract
        (a.metadata ->> 'genre')::TEXT                       AS genre,
        w.balance                                             AS wallet_balance,

        -- Subquery 1: Tổng doanh thu thực nhận từ contract splits
        -- Resolve artist via beneficiaries ISA table (V3 schema)
        (
            SELECT COALESCE(SUM(r.amount * cs.share_percentage), 0)
            FROM contract_splits cs
            JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
            JOIN revenue_logs r ON cs.track_id = r.track_id
            WHERE ab.artist_id = a.artist_id
        )                                                     AS total_earned,

        -- Subquery 2: Tổng đã rút thành công
        -- idx_withdraw_artist (B-Tree)
        (
            SELECT COALESCE(SUM(wd.amount), 0)
            FROM withdrawals wd
            WHERE wd.artist_id = a.artist_id
              AND wd.status = 'COMPLETED'
        )                                                     AS total_withdrawn,

        -- Subquery 3: Tổng đang chờ rút
        -- idx_withdraw_pending (Partial: status='PENDING')
        (
            SELECT COALESCE(SUM(wd.amount), 0)
            FROM withdrawals wd
            WHERE wd.artist_id = a.artist_id
              AND wd.status = 'PENDING'
        )                                                     AS pending_withdrawal,

        -- Chênh lệch: earned - withdrawn - balance (phải = 0 nếu đúng)
        (
            SELECT COALESCE(SUM(r.amount * cs.share_percentage), 0)
            FROM contract_splits cs
            JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
            JOIN revenue_logs r ON cs.track_id = r.track_id
            WHERE ab.artist_id = a.artist_id
        ) - (
            SELECT COALESCE(SUM(wd.amount), 0)
            FROM withdrawals wd
            WHERE wd.artist_id = a.artist_id
              AND wd.status = 'COMPLETED'
        ) - w.balance                                         AS chenh_lech,

        -- Đánh giá trạng thái audit
        CASE
            WHEN ABS(
                (SELECT COALESCE(SUM(r.amount * cs.share_percentage), 0)
                 FROM contract_splits cs
                 JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
                 JOIN revenue_logs r ON cs.track_id = r.track_id
                 WHERE ab.artist_id = a.artist_id)
                - (SELECT COALESCE(SUM(wd.amount), 0)
                   FROM withdrawals wd
                   WHERE wd.artist_id = a.artist_id AND wd.status = 'COMPLETED')
                - w.balance
            ) < 0.01 THEN 'OK'
            ELSE 'CẢNH BÁO'
        END::VARCHAR                                          AS trang_thai
    FROM artists a
    JOIN artist_wallets w ON a.artist_id = w.artist_id
    LEFT JOIN labels l    ON a.label_id = l.label_id
    ORDER BY chenh_lech DESC;
END; $$;

-- Gọi:
-- SELECT * FROM sp_wallet_audit_report();


-- ============================================================
-- SP7: THỐNG KÊ SỰ KIỆN & DOANH THU LIVE THEO VENUE
--      (CTE + Window + ROLLUP + Subquery)
-- ============================================================
-- Tận dụng:
--   • idx_events_venue (B-Tree) cho GROUP BY venue
--   • event_performers (M:N) để liên kết events ↔ artists
--   • live_revenue_details ISA table liên kết events
--   • ROLLUP cho subtotals venue + grand total
-- ============================================================
CREATE OR REPLACE FUNCTION sp_venue_event_analytics(
    p_year INT DEFAULT 2024
)
RETURNS TABLE (
    venue_name    VARCHAR,
    nghe_si       VARCHAR,
    so_su_kien    BIGINT,
    tong_ve_ban   BIGINT,
    doanh_thu_live NUMERIC,
    avg_ve_per_event NUMERIC,
    xep_hang_venue BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    WITH event_stats AS (
        -- CTE: aggregate events + live revenue per (venue, artist, event)
        SELECT
            v.venue_name,
            a.stage_name,
            e.event_id,
            -- Subquery: tổng vé bán từ live_revenue_details
            (
                SELECT COALESCE(SUM(lrd.ticket_sold), 0)
                FROM live_revenue_details lrd
                WHERE lrd.event_id = e.event_id
            )                                            AS tickets,
            -- Subquery: tổng doanh thu live
            (
                SELECT COALESCE(SUM(r.amount), 0)
                FROM live_revenue_details lrd
                JOIN revenue_logs r ON r.log_id = lrd.log_id
                WHERE lrd.event_id = e.event_id
            )                                            AS rev
        FROM events e
        -- idx_events_venue (B-Tree)
        JOIN venues v           ON e.venue_id   = v.venue_id
        -- event_performers M:N → artists (events has no direct artist_id)
        JOIN event_performers ep ON ep.event_id  = e.event_id
        JOIN artists a           ON a.artist_id  = ep.artist_id
        WHERE EXTRACT(YEAR FROM e.event_date) = p_year
          AND e.status IN ('COMPLETED', 'SCHEDULED')
    )
    SELECT
        COALESCE(es.venue_name, '★ TỔNG CỘNG ★')::VARCHAR,
        COALESCE(es.stage_name, '— Tất cả —')::VARCHAR,
        COUNT(DISTINCT es.event_id),
        SUM(es.tickets)::BIGINT,
        SUM(es.rev),
        ROUND(
            SUM(es.tickets)::NUMERIC
            / NULLIF(COUNT(DISTINCT es.event_id), 0), 0
        ),
        -- Window function: xếp hạng venue theo doanh thu
        DENSE_RANK() OVER (
            ORDER BY SUM(es.rev) DESC
        )
    FROM event_stats es
    GROUP BY ROLLUP(es.venue_name, es.stage_name)
    ORDER BY es.venue_name NULLS LAST, es.stage_name NULLS LAST;
END; $$;

-- Gọi:
-- SELECT * FROM sp_venue_event_analytics(2024);


-- ============================================================
-- BONUS: REFRESH MATERIALIZED VIEWS
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


-- ============================================================
-- BONUS: SP8 — TÌM NGHỆ SĨ THEO METADATA JSONB
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
            SELECT COUNT(*)
            FROM tracks t
            JOIN albums al ON t.album_id = al.album_id
            WHERE al.artist_id = a.artist_id
        ),
        -- Subquery tổng plays
        (
            SELECT COALESCE(SUM(t.play_count), 0)
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