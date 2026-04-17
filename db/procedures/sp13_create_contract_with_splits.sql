-- ============================================================
-- SP13: TẠO HỢP ĐỒNG + TẤT CẢ SPLITS (OLTP)
--       JSONB array input, BR-01 pre-validation (total share ≤ 1.0),
--       ISA discriminator-based subtype insert.
-- Synced from: ALL_STORED_PROCEDURES.md
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_create_contract_with_splits(
    p_name            VARCHAR,
    p_start_date      DATE,
    p_end_date        DATE,
    p_contract_type   VARCHAR,        -- 'recording' | 'distribution' | 'publishing'
    p_type_data       JSONB,          -- subtype-specific fields
    p_track_id        INT,
    p_splits          JSONB,          -- [{"beneficiary_id": N, "share": 0.X, "role": "..."}]
    OUT new_contract_id UUID
) LANGUAGE plpgsql AS $$
DECLARE
    v_split    JSONB;
    v_total    NUMERIC := 0;
BEGIN
    -- BR-01: Pre-validate total share ≤ 1.0
    FOR v_split IN SELECT * FROM jsonb_array_elements(p_splits) LOOP
        v_total := v_total + (v_split->>'share')::NUMERIC;
    END LOOP;

    IF v_total > 1.0001 THEN  -- float tolerance
        RAISE EXCEPTION 'BR-01 violated: total share = % > 1.0', ROUND(v_total, 4);
    END IF;

    -- Date validation
    IF p_end_date <= p_start_date THEN
        RAISE EXCEPTION 'end_date (%) must be after start_date (%)', p_end_date, p_start_date;
    END IF;

    -- 1. INSERT contract (parent)
    INSERT INTO contracts (name, start_date, end_date, contract_type, status)
    VALUES (p_name, p_start_date, p_end_date, p_contract_type, 'active')
    RETURNING contract_id INTO new_contract_id;

    -- 2. INSERT ISA subtype using discriminator
    CASE p_contract_type
        WHEN 'recording' THEN
            INSERT INTO recording_contracts (contract_id, advance_amount, album_commitment_quantity, exclusivity_years)
            VALUES (new_contract_id,
                    COALESCE((p_type_data->>'advance_amount')::NUMERIC, 0),
                    COALESCE((p_type_data->>'album_commitment_quantity')::INT, 1),
                    COALESCE((p_type_data->>'exclusivity_years')::INT, 1));
        WHEN 'distribution' THEN
            INSERT INTO distribution_contracts (contract_id, territory, distribution_fee_pct)
            VALUES (new_contract_id,
                    COALESCE(p_type_data->>'territory', 'Vietnam'),
                    COALESCE((p_type_data->>'distribution_fee_pct')::NUMERIC, 10));
        WHEN 'publishing' THEN
            INSERT INTO publishing_contracts (contract_id, copyright_owner, sync_rights_included)
            VALUES (new_contract_id,
                    COALESCE(p_type_data->>'copyright_owner', p_name),
                    COALESCE((p_type_data->>'sync_rights_included')::BOOLEAN, FALSE));
        ELSE
            RAISE EXCEPTION 'Invalid contract_type: "%"', p_contract_type;
    END CASE;

    -- 3. INSERT all splits
    FOR v_split IN SELECT * FROM jsonb_array_elements(p_splits) LOOP
        INSERT INTO contract_splits (contract_id, track_id, beneficiary_id, share_percentage, role)
        VALUES (
            new_contract_id,
            p_track_id,
            (v_split->>'beneficiary_id')::INT,
            (v_split->>'share')::NUMERIC,
            v_split->>'role'
        );
    END LOOP;

    RAISE NOTICE 'Contract "%" created (%) with % splits',
        p_name, new_contract_id, jsonb_array_length(p_splits);
END $$;

-- Sample call:
-- CALL sp_create_contract_with_splits(
--     'Sơn Tùng x MTP Recording', '2024-01-01', '2027-12-31', 'recording',
--     '{"advance_amount": 5000000000, "album_commitment_quantity": 3, "exclusivity_years": 5}'::jsonb,
--     1,
--     '[{"beneficiary_id": 1, "share": 0.7, "role": "Ca sĩ"},
--       {"beneficiary_id": 2, "share": 0.3, "role": "Label"}]'::jsonb,
--     NULL
-- );
