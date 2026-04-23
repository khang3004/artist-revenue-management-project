-- ============================================================
-- SP4: PHÂN CHIA DOANH THU THEO HỢP ĐỒNG (Polymorphic beneficiary + subquery)
-- Synced from: ALL_STORED_PROCEDURES.md
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
        c.name::VARCHAR,
        c.status::VARCHAR,
        t.title::VARCHAR,
        COALESCE(a_ben.stage_name, l_ben.name)::VARCHAR,
        CASE WHEN ab.beneficiary_id IS NOT NULL THEN 'Artist' ELSE 'Label' END::VARCHAR,
        cs.role::VARCHAR,
        cs.share_percentage,
        (SELECT COALESCE(SUM(r.amount), 0) FROM revenue_logs r WHERE r.track_id = t.track_id),
        ROUND((SELECT COALESCE(SUM(r.amount), 0) FROM revenue_logs r WHERE r.track_id = t.track_id) * cs.share_percentage, 2)
    FROM contracts c
    JOIN contract_splits cs ON c.contract_id = cs.contract_id
    JOIN tracks t           ON cs.track_id = t.track_id
    LEFT JOIN artist_beneficiaries ab ON ab.beneficiary_id = cs.beneficiary_id
    LEFT JOIN label_beneficiaries  lb ON lb.beneficiary_id = cs.beneficiary_id
    LEFT JOIN artists a_ben ON a_ben.artist_id = ab.artist_id
    LEFT JOIN labels  l_ben ON l_ben.label_id  = lb.label_id
    WHERE (p_contract_id IS NULL AND c.status = 'active')
       OR c.contract_id = p_contract_id
    ORDER BY c.name, actual_payout DESC;
END; $$;

-- Sample calls:
-- SELECT * FROM sp_contract_revenue_distribution();
-- SELECT * FROM sp_contract_revenue_distribution('00000000-0000-0000-0000-000000000000'::UUID);
