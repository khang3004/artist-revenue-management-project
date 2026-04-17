-- ============================================================
-- SP10: GHI NHẬN DOANH THU MỚI (OLTP)
--       Discriminator-based ISA insert, BR-03 (append-only),
--       BR-05 (live revenue → event_id).
-- Synced from: ALL_STORED_PROCEDURES.md
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_record_revenue(
    p_track_id        INT,
    p_amount          NUMERIC,
    p_currency        VARCHAR DEFAULT 'VND',
    p_revenue_type    VARCHAR,            -- 'streaming' | 'sync' | 'live'
    p_raw_data        JSONB DEFAULT '{}',
    -- Streaming params
    p_stream_count    BIGINT DEFAULT NULL,
    p_per_stream_rate NUMERIC DEFAULT NULL,
    p_platform        VARCHAR DEFAULT NULL,
    -- Sync params
    p_licensee_name   VARCHAR DEFAULT NULL,
    p_usage_type      VARCHAR DEFAULT NULL,
    -- Live params
    p_event_id        INT DEFAULT NULL,
    p_ticket_sold     INT DEFAULT NULL,
    OUT new_log_id    BIGINT
) LANGUAGE plpgsql AS $$
BEGIN
    -- Validation
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Amount must be positive (got %). Use reversal for refunds.', p_amount;
    END IF;

    IF p_revenue_type NOT IN ('streaming', 'sync', 'live') THEN
        RAISE EXCEPTION 'Invalid revenue_type: "%". Expected: streaming | sync | live', p_revenue_type;
    END IF;

    -- BR-05: Live revenue must link event
    IF p_revenue_type = 'live' AND p_event_id IS NULL THEN
        RAISE EXCEPTION 'BR-05 violated: Live revenue must have event_id';
    END IF;

    -- 1. INSERT parent (append-only — BR-03)
    INSERT INTO revenue_logs (track_id, amount, currency, log_date, raw_data, revenue_type, source)
    VALUES (p_track_id, p_amount, p_currency, NOW(), p_raw_data, p_revenue_type,
            COALESCE(p_platform, p_licensee_name, 'live_event'))
    RETURNING log_id INTO new_log_id;

    -- 2. INSERT ISA child (disjoint, total)
    CASE p_revenue_type
        WHEN 'streaming' THEN
            INSERT INTO streaming_revenue_details (log_id, stream_count, per_stream_rate, platform)
            VALUES (new_log_id, p_stream_count, p_per_stream_rate, p_platform);
        WHEN 'sync' THEN
            INSERT INTO sync_revenue_details (log_id, licensee_name, usage_type)
            VALUES (new_log_id, p_licensee_name, p_usage_type);
        WHEN 'live' THEN
            INSERT INTO live_revenue_details (log_id, event_id, ticket_sold)
            VALUES (new_log_id, p_event_id, p_ticket_sold);
    END CASE;

    RAISE NOTICE 'Revenue logged: id=%, type=%, amount=% %', new_log_id, p_revenue_type, p_amount, p_currency;
END $$;

-- Sample calls:
-- -- Streaming
-- CALL sp_record_revenue(1, 85000000, 'VND', 'streaming', '{}'::jsonb,
--     2500000, 0.034, 'Spotify', NULL, NULL, NULL, NULL, NULL);
-- -- Live (requires event_id)
-- CALL sp_record_revenue(NULL, 2500000000, 'VND', 'live', '{}'::jsonb,
--     NULL, NULL, NULL, NULL, NULL, 1, 4800, NULL);
