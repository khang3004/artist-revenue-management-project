-- =============================================================================
-- V2__ISA_Artists.sql
-- Migration: ISA (Is-A) sub-type tables for the Artist hierarchy
-- Depends on: V1 (artists, labels)
-- Tables: artist_roles, bands, composers, producers, band_members
-- =============================================================================

-- =============================================================================
-- TABLE: artist_roles (Junction Table for Overlapping ISA)
-- An artist can hold multiple roles simultaneously (e.g., solo & composer).
-- =============================================================================
CREATE TABLE artist_roles
(
    artist_id INTEGER          NOT NULL REFERENCES artists (artist_id) ON DELETE CASCADE,
    role      artist_role_enum NOT NULL,
    PRIMARY KEY (artist_id, role)
);

COMMENT ON TABLE artist_roles IS 'Junction table to support overlapping roles (e.g. solo, composer, producer).';
COMMENT ON COLUMN artist_roles.artist_id IS 'FK → artists.';
COMMENT ON COLUMN artist_roles.role IS 'The specific role held by the artist.';

-- =============================================================================
-- TABLE: bands
-- A band is a group artist.
-- =============================================================================
CREATE TABLE bands
(
    artist_id      INTEGER PRIMARY KEY
        REFERENCES artists (artist_id) ON DELETE CASCADE,
    formation_date DATE,
    member_count   INTEGER CHECK (member_count > 0),
    is_active      BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE bands IS 'ISA sub-type: group/band performers.';
COMMENT ON COLUMN bands.artist_id IS 'PK + FK → artists.';
COMMENT ON COLUMN bands.formation_date IS 'Date the band was formed.';
COMMENT ON COLUMN bands.member_count IS 'Current number of members (must be > 0).';
COMMENT ON COLUMN bands.is_active IS 'Whether the band is currently active.';

-- =============================================================================
-- TABLE: composers
-- A composer writes music (may also be a performer).
-- =============================================================================
CREATE TABLE composers
(
    artist_id        INTEGER PRIMARY KEY
        REFERENCES artists (artist_id) ON DELETE CASCADE,
    pen_name         VARCHAR(100),
    num_compositions INTEGER NOT NULL DEFAULT 0 CHECK (num_compositions >= 0)
);

COMMENT ON TABLE composers IS 'ISA sub-type: music composers.';
COMMENT ON COLUMN composers.artist_id IS 'PK + FK → artists.';
COMMENT ON COLUMN composers.pen_name IS 'Pen/pseudonym used for composition credits.';
COMMENT ON COLUMN composers.num_compositions IS 'Total number of compositions registered.';

-- =============================================================================
-- TABLE: producers
-- A producer oversees recording and production of tracks.
-- =============================================================================
CREATE TABLE producers
(
    artist_id        INTEGER PRIMARY KEY
        REFERENCES artists (artist_id) ON DELETE CASCADE,
    studio_name      VARCHAR(150),
    production_style VARCHAR(100)
);

COMMENT ON TABLE producers IS 'ISA sub-type: music producers.';
COMMENT ON COLUMN producers.artist_id IS 'PK + FK → artists.';
COMMENT ON COLUMN producers.studio_name IS 'Primary recording studio name.';
COMMENT ON COLUMN producers.production_style IS 'Characteristic production style or genre.';

-- =============================================================================
-- TABLE: band_members
-- Association between bands and individual artists (members).
-- An artist can belong to multiple bands over time.
-- =============================================================================
CREATE TABLE band_members
(
    band_id            INTEGER NOT NULL REFERENCES bands (artist_id) ON DELETE CASCADE,
    artist_id          INTEGER NOT NULL REFERENCES artists (artist_id) ON DELETE CASCADE,
    join_date          DATE,
    leave_date         DATE,
    internal_split_pct NUMERIC(5, 4)
        CHECK (internal_split_pct >= 0 AND internal_split_pct <= 1),
    PRIMARY KEY (band_id, artist_id),
    CHECK (leave_date IS NULL OR leave_date > join_date)
);

COMMENT ON TABLE band_members IS 'Members of a band at any given time.';
COMMENT ON COLUMN band_members.band_id IS 'FK → bands (artist_id).';
COMMENT ON COLUMN band_members.artist_id IS 'FK → artists — the individual member.';
COMMENT ON COLUMN band_members.join_date IS 'Date the member joined.';
COMMENT ON COLUMN band_members.leave_date IS 'Date the member left (NULL = still active).';
COMMENT ON COLUMN band_members.internal_split_pct IS 'This member''s share of the band''s revenue slice (0–1).';

-- =============================================================================
-- INDEXES
-- =============================================================================
CREATE INDEX idx_band_members_band ON band_members (band_id);
CREATE INDEX idx_band_members_artist ON band_members (artist_id);
