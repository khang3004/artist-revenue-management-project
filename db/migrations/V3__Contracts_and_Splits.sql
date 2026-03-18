-- =============================================================================
-- V3__Contracts_and_Splits.sql
-- Migration: Contract hierarchy + beneficiary model + revenue splits
-- Depends on: V1 (labels, artists, tracks)
-- Tables: contracts, recording_contracts, distribution_contracts,
--         publishing_contracts, beneficiaries, artist_beneficiaries,
--         label_beneficiaries, contract_splits
-- =============================================================================

-- =============================================================================
-- TABLE: contracts
-- Base / parent contract entity.
-- Uses UUID as PK for global uniqueness.
-- =============================================================================
CREATE TABLE contracts
(
    contract_id   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name          VARCHAR(200) NOT NULL,
    start_date    DATE         NOT NULL,
    end_date      DATE,
    contract_type VARCHAR(20)  NOT NULL CHECK (contract_type IN ('recording', 'distribution', 'publishing')),
    status        VARCHAR(20)  NOT NULL DEFAULT 'active'
                               CHECK (status IN ('active', 'expired', 'terminated', 'draft')),
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_contracts_dates
        CHECK (end_date IS NULL OR end_date > start_date)
);

COMMENT ON TABLE  contracts             IS 'Base contract entity. Sub-typed via ISA into recording, distribution, publishing.';
COMMENT ON COLUMN contracts.contract_id IS 'UUID primary key — globally unique across systems.';
COMMENT ON COLUMN contracts.name        IS 'Human-readable contract name/title.';
COMMENT ON COLUMN contracts.start_date  IS 'Effective start date.';
COMMENT ON COLUMN contracts.end_date    IS 'Expiry date; NULL = open-ended.';
COMMENT ON COLUMN contracts.contract_type IS 'Discriminator for ISA sub-type (recording | distribution | publishing).';
COMMENT ON COLUMN contracts.status      IS 'Lifecycle status.';
COMMENT ON COLUMN contracts.created_at  IS 'Row creation timestamp.';

-- =============================================================================
-- TABLE: recording_contracts (ISA sub-type of contracts)
-- Governs the recording and exclusive rights between label and artist.
-- =============================================================================
CREATE TABLE recording_contracts
(
    contract_id               UUID PRIMARY KEY
        REFERENCES contracts (contract_id) ON DELETE CASCADE,
    advance_amount            NUMERIC(15, 4) CHECK (advance_amount >= 0),
    album_commitment_quantity INTEGER CHECK (album_commitment_quantity > 0),
    exclusivity_years         INTEGER CHECK (exclusivity_years > 0)
);

COMMENT ON TABLE recording_contracts IS 'ISA sub-type: recording deal.';
COMMENT ON COLUMN recording_contracts.contract_id IS 'PK + FK → contracts.';
COMMENT ON COLUMN recording_contracts.advance_amount IS 'Advance payment to artist (non-negative).';
COMMENT ON COLUMN recording_contracts.album_commitment_quantity IS 'Minimum album delivery obligation.';
COMMENT ON COLUMN recording_contracts.exclusivity_years IS 'Years of exclusivity.';

-- =============================================================================
-- TABLE: distribution_contracts (ISA sub-type of contracts)
-- Governs distribution rights by territory.
-- =============================================================================
CREATE TABLE distribution_contracts
(
    contract_id          UUID PRIMARY KEY
        REFERENCES contracts (contract_id) ON DELETE CASCADE,
    territory            VARCHAR(100)  NOT NULL, -- e.g. 'Global', 'Asia', 'Europe'
    distribution_fee_pct NUMERIC(5, 4) NOT NULL
        CHECK (distribution_fee_pct >= 0 AND distribution_fee_pct <= 1)
);

COMMENT ON TABLE distribution_contracts IS 'ISA sub-type: distribution deal.';
COMMENT ON COLUMN distribution_contracts.contract_id IS 'PK + FK → contracts.';
COMMENT ON COLUMN distribution_contracts.territory IS 'Geographic territory, e.g. Global, Asia-Pacific.';
COMMENT ON COLUMN distribution_contracts.distribution_fee_pct IS 'Distributor fee as a fraction of revenue (0–1).';

-- =============================================================================
-- TABLE: publishing_contracts (ISA sub-type of contracts)
-- Governs publishing rights (sync, mechanical, etc.).
-- =============================================================================
CREATE TABLE publishing_contracts
(
    contract_id          UUID PRIMARY KEY
        REFERENCES contracts (contract_id) ON DELETE CASCADE,
    copyright_owner      VARCHAR(200),
    sync_rights_included BOOLEAN NOT NULL DEFAULT FALSE
);

COMMENT ON TABLE publishing_contracts IS 'ISA sub-type: publishing deal.';
COMMENT ON COLUMN publishing_contracts.contract_id IS 'PK + FK → contracts.';
COMMENT ON COLUMN publishing_contracts.copyright_owner IS 'Entity holding copyright under this deal.';
COMMENT ON COLUMN publishing_contracts.sync_rights_included IS 'TRUE if sync/licensing rights are included.';

-- =============================================================================
-- TABLE: beneficiaries
-- Abstract entity representing any party that can receive a revenue split.
-- Uses a type discriminator (beneficiary_type) for the XOR constraint.
--   'A' = artist, 'L' = label
-- =============================================================================
CREATE TABLE beneficiaries
(
    beneficiary_id   SERIAL PRIMARY KEY,
    beneficiary_type CHAR(1) NOT NULL CHECK (beneficiary_type IN ('A', 'L'))
);

COMMENT ON TABLE beneficiaries IS 'Abstract beneficiary for contract revenue splits.';
COMMENT ON COLUMN beneficiaries.beneficiary_id IS 'Surrogate primary key.';
COMMENT ON COLUMN beneficiaries.beneficiary_type IS 'Discriminator: A=artist, L=label.';

-- =============================================================================
-- TABLE: artist_beneficiaries (ISA sub-type of beneficiaries)
-- A specific artist who receives a revenue share.
-- =============================================================================
CREATE TABLE artist_beneficiaries
(
    beneficiary_id INTEGER PRIMARY KEY
        REFERENCES beneficiaries (beneficiary_id) ON DELETE CASCADE,
    artist_id      INTEGER NOT NULL REFERENCES artists (artist_id) ON DELETE CASCADE
);

COMMENT ON TABLE public.artist_beneficiaries IS 'Beneficiary is an artist (ISA sub-type).';
COMMENT ON COLUMN public.artist_beneficiaries.beneficiary_id IS 'PK + FK → beneficiaries.';
COMMENT ON COLUMN public.artist_beneficiaries.artist_id IS 'FK → artists.';

-- =============================================================================
-- TABLE: label_beneficiaries (ISA sub-type of beneficiaries)
-- A record label that receives a revenue share.
-- =============================================================================
CREATE TABLE label_beneficiaries
(
    beneficiary_id INTEGER PRIMARY KEY
        REFERENCES beneficiaries (beneficiary_id) ON DELETE CASCADE,
    label_id       INTEGER NOT NULL REFERENCES labels (label_id) ON DELETE CASCADE
);

COMMENT ON TABLE label_beneficiaries IS 'Beneficiary is a label (ISA sub-type).';
COMMENT ON COLUMN label_beneficiaries.beneficiary_id IS 'PK + FK → beneficiaries.';
COMMENT ON COLUMN label_beneficiaries.label_id IS 'FK → labels.';

-- =============================================================================
-- TABLE: contract_splits (Weak Entity)
-- Defines the percentage of revenue each beneficiary receives for a given
-- track under a given contract.
-- The XOR constraint (either artist OR label beneficiary) is enforced by
-- the beneficiaries.beneficiary_type discriminator column.
-- =============================================================================
CREATE TABLE contract_splits
(
    split_id         SERIAL PRIMARY KEY,
    contract_id      UUID          NOT NULL REFERENCES contracts (contract_id) ON DELETE CASCADE,
    track_id         INTEGER       NOT NULL REFERENCES tracks (track_id) ON DELETE CASCADE,
    beneficiary_id   INTEGER       NOT NULL REFERENCES beneficiaries (beneficiary_id),
    share_percentage NUMERIC(5, 4) NOT NULL
        CHECK (share_percentage > 0 AND share_percentage <= 1),
    role             VARCHAR(50)   NOT NULL,
    UNIQUE (contract_id, track_id, beneficiary_id)
);

COMMENT ON TABLE contract_splits IS 'Weak entity: defines per-track revenue splits per contract.';
COMMENT ON COLUMN contract_splits.split_id IS 'Surrogate PK.';
COMMENT ON COLUMN contract_splits.contract_id IS 'FK → contracts.';
COMMENT ON COLUMN contract_splits.track_id IS 'FK → tracks.';
COMMENT ON COLUMN contract_splits.beneficiary_id IS 'FK → beneficiaries (either artist or label).';
COMMENT ON COLUMN contract_splits.share_percentage IS 'Fraction of revenue (0 exclusive to 1 inclusive).';
COMMENT ON COLUMN contract_splits.role IS 'Role in this split, e.g. performer, publisher, distributor.';

-- =============================================================================
-- INDEXES
-- =============================================================================
CREATE INDEX idx_contracts_status ON contracts (status);
CREATE INDEX idx_contract_splits_contract ON contract_splits (contract_id);
CREATE INDEX idx_contract_splits_track ON contract_splits (track_id);
CREATE INDEX idx_contract_splits_bene ON contract_splits (beneficiary_id);
CREATE INDEX idx_artist_bene_artist ON artist_beneficiaries (artist_id);
CREATE INDEX idx_label_bene_label ON label_beneficiaries (label_id);
