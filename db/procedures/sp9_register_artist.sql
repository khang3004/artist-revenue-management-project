-- ============================================================
-- SP9: ĐĂNG KÝ NGHỆ SĨ MỚI (OLTP)
--      Multi-table INSERT (atomicity), ISA enforcement,
--      auto-create wallet + beneficiary, BR validation.
-- Synced from: ALL_STORED_PROCEDURES.md
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_register_artist(
    p_stage_name      VARCHAR,
    p_full_name       VARCHAR,
    OUT new_artist_id INT,
    p_label_id        INT DEFAULT NULL,
    p_metadata        JSONB DEFAULT '{}',
    p_artist_type     VARCHAR DEFAULT 'solo',  -- 'solo' | 'band' | 'composer'
    p_vocal_range     VARCHAR DEFAULT NULL,
    p_pen_name        VARCHAR DEFAULT NULL,
    p_member_count    INT DEFAULT NULL
) LANGUAGE plpgsql AS $$
BEGIN
    -- 1. INSERT artist (parent)
    INSERT INTO artists (stage_name, full_name, label_id, metadata, debut_date)
    VALUES (p_stage_name, p_full_name, p_label_id, p_metadata, CURRENT_DATE)
    RETURNING artist_id INTO new_artist_id;

    -- 2. INSERT ISA subtype
    CASE p_artist_type
        WHEN 'solo' THEN
            INSERT INTO solo_artists (artist_id, vocal_range)
            VALUES (new_artist_id, p_vocal_range);
        WHEN 'band' THEN
            IF p_member_count IS NULL OR p_member_count < 2 THEN
                RAISE EXCEPTION 'Band must have >= 2 members (got %)', p_member_count;
            END IF;
            INSERT INTO bands (artist_id, formation_date, member_count, is_active)
            VALUES (new_artist_id, CURRENT_DATE, p_member_count, TRUE);
        WHEN 'composer' THEN
            INSERT INTO composers (artist_id, pen_name, num_compositions)
            VALUES (new_artist_id, COALESCE(p_pen_name, p_stage_name), 0);
        ELSE
            RAISE EXCEPTION 'Invalid artist_type: %. Expected: solo | band | composer', p_artist_type;
    END CASE;

    -- 3. INSERT artist_wallet (weak entity, 1:1 — must exist)
    INSERT INTO artist_wallets (artist_id, balance)
    VALUES (new_artist_id, 0);

    -- 4. INSERT beneficiary (for contract_splits later)
    WITH new_ben AS (
        INSERT INTO beneficiaries (beneficiary_type)
        VALUES ('artist')
        RETURNING beneficiary_id
    )
    INSERT INTO artist_beneficiaries (beneficiary_id, artist_id)
    SELECT beneficiary_id, new_artist_id FROM new_ben;

    RAISE NOTICE 'Artist "%" registered → artist_id = %', p_stage_name, new_artist_id;
END $$;

-- Sample call:
-- CALL sp_register_artist(
--     'Sơn Tùng M-TP', 'Nguyễn Thanh Tùng', 1,
--     '{"genre": "pop"}'::jsonb, 'solo', 'C3-C6', NULL, NULL, NULL
-- );
