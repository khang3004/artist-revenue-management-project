-- =============================================================================
-- V7__align_with_spec.sql
-- Align database model with the data requirements specification (dac-ta).
--
-- Changes:
--   1. Add solo_artists ISA sub-type table (vocal_range, talent_agency)
--   2. Fix bands.member_count CHECK to >= 2
--   3. Add currency column to revenue_logs
--   4. Add notes column to events
--   5. Rename managers.phone_manager → manager_phone
--   6. Rename venues.address → venue_address
--   7. Add APPROVED to withdrawal_status_enum
--   8. Rename composers.num_compositions → total_works
--   9. Fix live_revenue_details.event_id to NOT NULL
-- =============================================================================

-- 1. solo_artists ISA sub-type ------------------------------------------------
CREATE TABLE solo_artists (
    artist_id     INTEGER PRIMARY KEY
        REFERENCES artists (artist_id) ON DELETE CASCADE,
    vocal_range   VARCHAR(50),
    talent_agency VARCHAR(150)
);

COMMENT ON TABLE  solo_artists              IS 'ISA sub-type: solo performing artists.';
COMMENT ON COLUMN solo_artists.artist_id    IS 'PK + FK → artists.';
COMMENT ON COLUMN solo_artists.vocal_range  IS 'Vocal range, e.g. tenor, soprano, baritone.';
COMMENT ON COLUMN solo_artists.talent_agency IS 'Name of the talent management agency.';

-- 2. Add bands.member_count (removed in V2 as derived, restored for SP usage) + CHECK >= 2
ALTER TABLE bands
    ADD COLUMN IF NOT EXISTS member_count INT;

ALTER TABLE bands
    DROP CONSTRAINT IF EXISTS bands_member_count_check;

ALTER TABLE bands
    ADD CONSTRAINT bands_member_count_check CHECK (member_count >= 2);

-- 3. Add currency to revenue_logs --------------------------------------------
ALTER TABLE revenue_logs
    ADD COLUMN IF NOT EXISTS currency VARCHAR(3) NOT NULL DEFAULT 'VND';

COMMENT ON COLUMN revenue_logs.currency IS 'ISO 4217 currency code, e.g. VND, USD.';

-- 4. Add notes to events -----------------------------------------------------
ALTER TABLE events
    ADD COLUMN IF NOT EXISTS notes TEXT;

COMMENT ON COLUMN events.notes IS 'Optional free-text notes for the event.';

-- 5. Rename managers.phone_manager → manager_phone ---------------------------
ALTER TABLE managers
    RENAME COLUMN phone_manager TO manager_phone;

-- 6. Rename venues.address → venue_address -----------------------------------
ALTER TABLE venues
    RENAME COLUMN address TO venue_address;

-- 7. Add APPROVED to withdrawal_status_enum ----------------------------------
ALTER TYPE withdrawal_status_enum ADD VALUE IF NOT EXISTS 'APPROVED';

-- 8. Rename composers.num_compositions → total_works -------------------------
ALTER TABLE composers
    RENAME COLUMN num_compositions TO total_works;

-- 9. Fix live_revenue_details.event_id to NOT NULL ---------------------------
-- First ensure no existing NULLs remain (set to a sentinel if any exist)
-- Then apply the NOT NULL constraint.
UPDATE live_revenue_details
SET event_id = (SELECT MIN(event_id) FROM events)
WHERE event_id IS NULL;

ALTER TABLE live_revenue_details
    ALTER COLUMN event_id SET NOT NULL;
