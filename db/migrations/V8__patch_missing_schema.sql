-- =============================================================================
-- V8__patch_missing_schema.sql
-- Comprehensive patch: bring Neon DB up to parity with V1–V7 for ETL pipeline.
--
-- Run via: db/migrations/apply_patch.py (handles multi-statement execution)
--
-- DB state before this patch (confirmed):
--   Tables: labels, artists (no birthday), albums, tracks,
--           contracts (no contract_type), recording_contracts,
--           distribution_contracts, publishing_contracts,
--           contract_splits (OLD schema: artist_id/label_id, no beneficiary_id),
--           bands, composers, solo_artists
--   Enums:  none
--   V2 missing: artist_roles, producers, band_members
--   V4 missing: venues, managers, events, event_performers
--   V5 missing: revenue_logs, *_revenue_details, artist_wallets, withdrawals
-- =============================================================================

-- ── 1. Missing columns on existing tables ────────────────────────────────────

ALTER TABLE artists
    ADD COLUMN IF NOT EXISTS birthday DATE;

ALTER TABLE contracts
    ADD COLUMN IF NOT EXISTS contract_type VARCHAR(20) NOT NULL DEFAULT 'recording';

-- end_date was NOT NULL in the old schema; the spec allows open-ended contracts
ALTER TABLE contracts
    ALTER COLUMN end_date DROP NOT NULL;

-- ── 1b. Rename mismatched columns on existing ISA sub-type tables ────────────

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name='recording_contracts' AND column_name='committed_albums') THEN
        ALTER TABLE recording_contracts RENAME COLUMN committed_albums TO album_commitment_quantity;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name='publishing_contracts' AND column_name='copyright_holder') THEN
        ALTER TABLE publishing_contracts RENAME COLUMN copyright_holder TO copyright_owner;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_name='publishing_contracts' AND column_name='sync_rights') THEN
        ALTER TABLE publishing_contracts RENAME COLUMN sync_rights TO sync_rights_included;
    END IF;
END $$;

-- ── 2. Enums (guarded with DO blocks — PG has no CREATE TYPE IF NOT EXISTS) ──

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'artist_role_enum') THEN
        CREATE TYPE artist_role_enum AS ENUM ('solo', 'band', 'composer', 'producer');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_status_enum') THEN
        CREATE TYPE event_status_enum AS ENUM ('SCHEDULED', 'COMPLETED', 'CANCELLED');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'revenue_type_enum') THEN
        CREATE TYPE revenue_type_enum AS ENUM ('STREAMING', 'SYNC', 'LIVE');
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'withdrawal_status_enum') THEN
        CREATE TYPE withdrawal_status_enum AS ENUM ('PENDING', 'REJECTED', 'COMPLETED', 'APPROVED');
    END IF;
END $$;

-- ── 3. V2: remaining ISA artist tables ───────────────────────────────────────

CREATE TABLE IF NOT EXISTS artist_roles
(
    artist_id INTEGER          NOT NULL REFERENCES artists (artist_id) ON DELETE CASCADE,
    role      artist_role_enum NOT NULL,
    PRIMARY KEY (artist_id, role)
);

CREATE TABLE IF NOT EXISTS producers
(
    artist_id        INTEGER PRIMARY KEY REFERENCES artists (artist_id) ON DELETE CASCADE,
    studio_name      VARCHAR(150),
    production_style VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS band_members
(
    band_id            INTEGER NOT NULL REFERENCES bands (artist_id) ON DELETE CASCADE,
    artist_id          INTEGER NOT NULL REFERENCES artists (artist_id) ON DELETE CASCADE,
    join_date          DATE,
    leave_date         DATE,
    internal_split_pct NUMERIC(5, 4) CHECK (internal_split_pct >= 0 AND internal_split_pct <= 1),
    PRIMARY KEY (band_id, artist_id),
    CHECK (leave_date IS NULL OR leave_date > join_date)
);

-- ── 4. contract_splits restructure ───────────────────────────────────────────
-- Old schema: artist_id / label_id columns (no beneficiaries hierarchy)
-- New schema: beneficiary_id → beneficiaries ISA table
-- Drop old table first (seed data; ETL repopulates), then create supporting
-- tables and the new contract_splits.

DROP TABLE IF EXISTS contract_splits;

CREATE TABLE IF NOT EXISTS beneficiaries
(
    beneficiary_id   SERIAL PRIMARY KEY,
    beneficiary_type CHAR(1) NOT NULL CHECK (beneficiary_type IN ('A', 'L'))
);

CREATE TABLE IF NOT EXISTS artist_beneficiaries
(
    beneficiary_id INTEGER PRIMARY KEY REFERENCES beneficiaries (beneficiary_id) ON DELETE CASCADE,
    artist_id      INTEGER NOT NULL REFERENCES artists (artist_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS label_beneficiaries
(
    beneficiary_id INTEGER PRIMARY KEY REFERENCES beneficiaries (beneficiary_id) ON DELETE CASCADE,
    label_id       INTEGER NOT NULL REFERENCES labels (label_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS contract_splits
(
    split_id         SERIAL PRIMARY KEY,
    contract_id      UUID          NOT NULL REFERENCES contracts (contract_id) ON DELETE CASCADE,
    track_id         INTEGER       NOT NULL REFERENCES tracks (track_id) ON DELETE CASCADE,
    beneficiary_id   INTEGER       NOT NULL REFERENCES beneficiaries (beneficiary_id),
    share_percentage NUMERIC(5, 4) NOT NULL CHECK (share_percentage > 0 AND share_percentage <= 1),
    role             VARCHAR(50)   NOT NULL,
    UNIQUE (contract_id, track_id, beneficiary_id)
);

-- ── 5. V4 + V7: event infrastructure ─────────────────────────────────────────
-- Column names are post-V7: venue_address, manager_phone, events.notes

CREATE TABLE IF NOT EXISTS venues
(
    venue_id      SERIAL       PRIMARY KEY,
    venue_name    VARCHAR(200) NOT NULL,
    venue_address VARCHAR(300),
    capacity      INTEGER      CHECK (capacity > 0)
);

CREATE TABLE IF NOT EXISTS managers
(
    manager_id    SERIAL       PRIMARY KEY,
    manager_name  VARCHAR(150) NOT NULL,
    manager_phone VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS events
(
    event_id   SERIAL            PRIMARY KEY,
    event_name VARCHAR(200)      NOT NULL,
    event_date TIMESTAMP         NOT NULL,
    venue_id   INTEGER           REFERENCES venues   (venue_id)   ON DELETE SET NULL,
    manager_id INTEGER           REFERENCES managers (manager_id) ON DELETE SET NULL,
    status     event_status_enum NOT NULL DEFAULT 'SCHEDULED',
    notes      TEXT
);

CREATE TABLE IF NOT EXISTS event_performers
(
    event_id          INTEGER NOT NULL REFERENCES events  (event_id)  ON DELETE CASCADE,
    artist_id         INTEGER NOT NULL REFERENCES artists (artist_id) ON DELETE CASCADE,
    performance_fee   NUMERIC(15, 2) CHECK (performance_fee >= 0),
    revenue_share_pct NUMERIC(5, 4)  CHECK (revenue_share_pct >= 0 AND revenue_share_pct <= 1),
    PRIMARY KEY (event_id, artist_id)
);

-- ── 6. V5: revenue and wallet tables ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS revenue_logs
(
    log_id       BIGSERIAL         PRIMARY KEY,
    track_id     INTEGER           REFERENCES tracks (track_id) ON DELETE SET NULL,
    source       VARCHAR(50)       NOT NULL,
    amount       NUMERIC(15, 4)    NOT NULL DEFAULT 0 CHECK (amount >= 0),
    log_date     TIMESTAMP         NOT NULL DEFAULT NOW(),
    raw_data     JSONB,
    revenue_type revenue_type_enum NOT NULL,
    currency     VARCHAR(3)        NOT NULL DEFAULT 'VND'
);

CREATE TABLE IF NOT EXISTS streaming_revenue_details
(
    log_id          BIGINT        PRIMARY KEY REFERENCES revenue_logs (log_id) ON DELETE CASCADE,
    stream_count    INTEGER       NOT NULL CHECK (stream_count >= 0),
    per_stream_rate NUMERIC(10, 6) NOT NULL CHECK (per_stream_rate >= 0),
    platform        VARCHAR(50)   NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_revenue_details
(
    log_id        BIGINT       PRIMARY KEY REFERENCES revenue_logs (log_id) ON DELETE CASCADE,
    licensee_name VARCHAR(200) NOT NULL,
    usage_type    VARCHAR(50)  NOT NULL
);

CREATE TABLE IF NOT EXISTS live_revenue_details
(
    log_id      BIGINT   PRIMARY KEY REFERENCES revenue_logs (log_id) ON DELETE CASCADE,
    event_id    INTEGER  REFERENCES events (event_id) ON DELETE SET NULL,
    ticket_sold INTEGER  CHECK (ticket_sold >= 0)
);

CREATE TABLE IF NOT EXISTS artist_wallets
(
    artist_id INTEGER        PRIMARY KEY REFERENCES artists (artist_id) ON DELETE CASCADE,
    balance   NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (balance >= 0)
);

CREATE TABLE IF NOT EXISTS withdrawals
(
    withdrawal_id SERIAL                    PRIMARY KEY,
    artist_id     INTEGER                   NOT NULL REFERENCES artists (artist_id) ON DELETE RESTRICT,
    amount        NUMERIC(15, 2)            NOT NULL CHECK (amount > 0),
    status        withdrawal_status_enum    NOT NULL DEFAULT 'PENDING',
    requested_at  TIMESTAMP                 NOT NULL DEFAULT NOW(),
    processed_at  TIMESTAMP,
    method        VARCHAR(50),
    note          JSONB
);

-- ── 7. Indexes ────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_band_members_band      ON band_members             (band_id);
CREATE INDEX IF NOT EXISTS idx_band_members_artist    ON band_members             (artist_id);
CREATE INDEX IF NOT EXISTS idx_contract_splits_contract ON contract_splits        (contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_splits_track  ON contract_splits          (track_id);
CREATE INDEX IF NOT EXISTS idx_contract_splits_bene   ON contract_splits          (beneficiary_id);
CREATE INDEX IF NOT EXISTS idx_artist_bene_artist     ON artist_beneficiaries     (artist_id);
CREATE INDEX IF NOT EXISTS idx_label_bene_label       ON label_beneficiaries      (label_id);
CREATE INDEX IF NOT EXISTS idx_events_venue           ON events                   (venue_id);
CREATE INDEX IF NOT EXISTS idx_events_manager         ON events                   (manager_id);
CREATE INDEX IF NOT EXISTS idx_events_date            ON events                   (event_date);
CREATE INDEX IF NOT EXISTS idx_eperformers_event      ON event_performers         (event_id);
CREATE INDEX IF NOT EXISTS idx_eperformers_artist     ON event_performers         (artist_id);
CREATE INDEX IF NOT EXISTS idx_revenue_logs_track     ON revenue_logs             (track_id);
CREATE INDEX IF NOT EXISTS idx_revenue_logs_date      ON revenue_logs             (log_date);
CREATE INDEX IF NOT EXISTS idx_revenue_logs_type      ON revenue_logs             (revenue_type);
CREATE INDEX IF NOT EXISTS idx_live_rev_event         ON live_revenue_details     (event_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_artist     ON withdrawals              (artist_id);
CREATE INDEX IF NOT EXISTS idx_withdrawals_status     ON withdrawals              (status);
