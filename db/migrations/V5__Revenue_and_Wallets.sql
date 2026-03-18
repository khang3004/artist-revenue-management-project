-- =============================================================================
-- V5__Revenue_and_Wallets.sql
-- Migration: Revenue streams, wallets, and withdrawal requests
-- Depends on: V1 (artists, tracks), V3 (contracts, contract_splits),
--             V4 (events)
-- Tables: revenue_logs, streaming_revenue_details, sync_revenue_details,
--         live_revenue_details, artist_wallets, withdrawals
-- =============================================================================

CREATE TYPE revenue_type_enum AS ENUM (
    'STREAMING',
    'SYNC',
    'LIVE'
);

CREATE TYPE withdrawal_status_enum AS ENUM (
    'PENDING',
    'REJECTED',
    'COMPLETED'
);

-- =============================================================================
-- TABLE: revenue_logs
-- Central fact table for every revenue event.
-- revenue_type is an ISA discriminator:
--   'streaming' → streaming_revenue_details
--   'sync'      → sync_revenue_details
--   'live'      → live_revenue_details
-- =============================================================================
CREATE TABLE revenue_logs (
    log_id       BIGSERIAL    PRIMARY KEY,
    track_id     INTEGER      REFERENCES tracks (track_id) ON DELETE SET NULL,
    source       VARCHAR(50)  NOT NULL,
    amount       NUMERIC(15, 4) NOT NULL DEFAULT 0
                     CHECK (amount >= 0),
    log_date     TIMESTAMP    NOT NULL DEFAULT NOW(),
    raw_data     JSONB,
    revenue_type revenue_type_enum NOT NULL
);

COMMENT ON TABLE  revenue_logs              IS 'Master fact table for all revenue events (ISA parent).';
COMMENT ON COLUMN revenue_logs.log_id       IS 'Big-serial surrogate PK; high-volume table.';
COMMENT ON COLUMN revenue_logs.track_id     IS 'FK → tracks. NULL for venue/event-only revenue.';
COMMENT ON COLUMN revenue_logs.source       IS 'Source system or platform name, e.g. Spotify.';
COMMENT ON COLUMN revenue_logs.amount       IS 'Gross revenue amount; must be non-negative.';
COMMENT ON COLUMN revenue_logs.log_date     IS 'Timestamp the revenue event was recorded.';
COMMENT ON COLUMN revenue_logs.raw_data     IS 'Raw payload from the source system (JSONB).';
COMMENT ON COLUMN revenue_logs.revenue_type IS 'ISA discriminator: streaming | sync | live.';

-- =============================================================================
-- TABLE: streaming_revenue_details (ISA sub-type)
-- Extra data for streaming revenue events.
-- =============================================================================
CREATE TABLE streaming_revenue_details (
    log_id          BIGINT       PRIMARY KEY
                                 REFERENCES revenue_logs (log_id) ON DELETE CASCADE,
    stream_count    INTEGER      NOT NULL CHECK (stream_count >= 0),
    per_stream_rate NUMERIC(10, 6) NOT NULL CHECK (per_stream_rate >= 0),
    platform        VARCHAR(50)  NOT NULL   -- e.g. Spotify, Apple Music, TIDAL, YouTube Music
);

COMMENT ON TABLE  streaming_revenue_details                IS 'ISA sub-type: streaming revenue details.';
COMMENT ON COLUMN streaming_revenue_details.log_id         IS 'PK + FK → revenue_logs.';
COMMENT ON COLUMN streaming_revenue_details.stream_count   IS 'Number of streams in this reporting period.';
COMMENT ON COLUMN streaming_revenue_details.per_stream_rate IS 'Rate per stream in base currency.';
COMMENT ON COLUMN streaming_revenue_details.platform       IS 'Streaming platform, e.g. Spotify, Apple Music.';

-- =============================================================================
-- TABLE: sync_revenue_details (ISA sub-type)
-- Extra data for sync licensing revenue events.
-- =============================================================================
CREATE TABLE sync_revenue_details (
    log_id        BIGINT      PRIMARY KEY
                              REFERENCES revenue_logs (log_id) ON DELETE CASCADE,
    licensee_name VARCHAR(200) NOT NULL,
    usage_type    VARCHAR(50)  NOT NULL   -- e.g. TV, Film, Ad
);

COMMENT ON TABLE  sync_revenue_details              IS 'ISA sub-type: sync/licensing revenue details.';
COMMENT ON COLUMN sync_revenue_details.log_id       IS 'PK + FK → revenue_logs.';
COMMENT ON COLUMN sync_revenue_details.licensee_name IS 'Name/title of the licensee/buyer.';
COMMENT ON COLUMN sync_revenue_details.usage_type   IS 'Media type: TV, Film, Advertisement, etc.';

-- =============================================================================
-- TABLE: live_revenue_details (ISA sub-type)
-- Extra data for live-performance revenue events.
-- =============================================================================
CREATE TABLE live_revenue_details (
    log_id      BIGINT   PRIMARY KEY
                         REFERENCES revenue_logs (log_id) ON DELETE CASCADE,
    event_id    INTEGER  REFERENCES events (event_id) ON DELETE SET NULL,
    ticket_sold INTEGER  CHECK (ticket_sold >= 0)
);

COMMENT ON TABLE  live_revenue_details            IS 'ISA sub-type: live performance revenue details.';
COMMENT ON COLUMN live_revenue_details.log_id     IS 'PK + FK → revenue_logs.';
COMMENT ON COLUMN live_revenue_details.event_id   IS 'FK → events. NULL if event not tracked.';
COMMENT ON COLUMN live_revenue_details.ticket_sold IS 'Number of tickets sold for this performance.';

-- =============================================================================
-- TABLE: artist_wallets (Weak Entity)
-- One wallet per artist. Balance accumulates from revenue splits and
-- decreases only when a withdrawal is completed.
-- =============================================================================
CREATE TABLE artist_wallets (
    artist_id  INTEGER        PRIMARY KEY
                              REFERENCES artists (artist_id) ON DELETE CASCADE,
    balance    NUMERIC(15, 2) NOT NULL DEFAULT 0
                              CHECK (balance >= 0)
);

COMMENT ON TABLE  artist_wallets           IS 'Weak entity: one wallet per artist, holds payable balance.';
COMMENT ON COLUMN artist_wallets.artist_id IS 'PK (partial key) + FK → artists.';
COMMENT ON COLUMN artist_wallets.balance   IS 'Current payable balance. Must be non-negative.';

-- =============================================================================
-- TABLE: withdrawals
-- A withdrawal request by an artist against their wallet.
-- Business Rule BR-02: balance decreases ONLY when status transitions
-- to 'completed' (enforced in V6 via trigger).
-- =============================================================================
CREATE TABLE withdrawals (
    withdrawal_id  SERIAL         PRIMARY KEY,
    artist_id      INTEGER        NOT NULL REFERENCES artists (artist_id) ON DELETE RESTRICT,
    amount         NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    status         withdrawal_status_enum NOT NULL DEFAULT 'PENDING',
    requested_at   TIMESTAMP      NOT NULL DEFAULT NOW(),
    processed_at   TIMESTAMP,
    method         VARCHAR(50),
    note           JSONB
);

COMMENT ON TABLE  withdrawals                IS 'Withdrawal requests by artists against their wallets.';
COMMENT ON COLUMN withdrawals.withdrawal_id  IS 'Surrogate primary key.';
COMMENT ON COLUMN withdrawals.artist_id      IS 'FK → artists. Who is requesting the withdrawal.';
COMMENT ON COLUMN withdrawals.amount         IS 'Requested amount; must be positive.';
COMMENT ON COLUMN withdrawals.status         IS 'Lifecycle: PENDING | REJECTED | COMPLETED.';
COMMENT ON COLUMN withdrawals.requested_at   IS 'Timestamp the request was submitted.';
COMMENT ON COLUMN withdrawals.processed_at   IS 'Timestamp the request was approved or rejected.';
COMMENT ON COLUMN withdrawals.method         IS 'Payment method: bank_transfer, paypal, etc.';
COMMENT ON COLUMN withdrawals.note           IS 'Optional JSONB payload with extra metadata.';

-- =============================================================================
-- INDEXES
-- =============================================================================
CREATE INDEX idx_revenue_logs_track    ON revenue_logs (track_id);
CREATE INDEX idx_revenue_logs_date     ON revenue_logs (log_date);
CREATE INDEX idx_revenue_logs_type     ON revenue_logs (revenue_type);
CREATE INDEX idx_withdrawals_artist    ON withdrawals  (artist_id);
CREATE INDEX idx_withdrawals_status    ON withdrawals  (status);
CREATE INDEX idx_live_rev_event        ON live_revenue_details (event_id);
