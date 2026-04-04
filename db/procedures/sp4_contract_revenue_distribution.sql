-- ============================================================
-- MDL018 — HỆ THỐNG QUẢN LÝ DOANH THU NGHỆ SĨ V-POP
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
