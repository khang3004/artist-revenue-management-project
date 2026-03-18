-- =============================================================================
-- V1__Core_Entities.sql
-- Migration: Core foundational tables with no (or minimal) dependencies
-- Tables: labels, artists, albums, tracks
-- =============================================================================

-- Enable pgcrypto for UUID generation (needed later in V3)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- ENUM TYPES
-- =============================================================================

-- Artist role enum (an artist can hold multiple roles)
CREATE TYPE artist_role_enum AS ENUM (
    'solo',
    'band',
    'composer',
    'producer'
    );

-- =============================================================================
-- TABLE: labels
-- Record labels that manage artists
-- No foreign-key dependencies → created first
-- =============================================================================
CREATE TABLE labels
(
    label_id      SERIAL PRIMARY KEY,
    name          VARCHAR(150) NOT NULL UNIQUE,
    founded_date  DATE,
    contact_email VARCHAR(100),
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE labels IS 'Record labels that sign and manage artists.';
COMMENT ON COLUMN labels.label_id IS 'Surrogate primary key.';
COMMENT ON COLUMN labels.name IS 'Unique human-readable label name.';
COMMENT ON COLUMN labels.founded_date IS 'Date the label was established.';
COMMENT ON COLUMN labels.contact_email IS 'Primary contact e-mail for the label.';
COMMENT ON COLUMN labels.created_at IS 'Row creation timestamp.';

-- =============================================================================
-- TABLE: artists
-- Parent entity in the ISA (Is-A) hierarchy.
-- Every sub-type (solo_artist, band, composer, producer) will
-- reference artist_id as its PK+FK.
-- =============================================================================
CREATE TABLE artists
(
    artist_id  SERIAL PRIMARY KEY,
    stage_name VARCHAR(100) NOT NULL,
    full_name  VARCHAR(150),
    debut_date DATE,
    birthday   DATE,
    metadata   JSONB, -- e.g. social-media links, biography snippets
    label_id   INTEGER      REFERENCES labels (label_id) ON DELETE SET NULL,
    created_at TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP    NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE artists IS 'Parent entity for all artist types (ISA hierarchy).';
COMMENT ON COLUMN artists.artist_id IS 'Surrogate primary key.';
COMMENT ON COLUMN artists.stage_name IS 'Public stage/artist name. Must not be null.';
COMMENT ON COLUMN artists.full_name IS 'Legal birth/full name.';
COMMENT ON COLUMN artists.debut_date IS 'Date of public debut.';
COMMENT ON COLUMN artists.birthday IS 'Date of birth.';
COMMENT ON COLUMN artists.metadata IS 'Flexible JSONB for social links, bio, etc.';
COMMENT ON COLUMN artists.label_id IS 'FK → labels. NULL if unaffiliated.';
COMMENT ON COLUMN artists.created_at IS 'Row creation timestamp.';
COMMENT ON COLUMN artists.updated_at IS 'Last modification timestamp (managed by trigger).';

-- Trigger to auto-update updated_at on every row change
CREATE OR REPLACE FUNCTION fn_set_updated_at()
    RETURNS TRIGGER
    LANGUAGE plpgsql AS
$$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_artists_updated_at
    BEFORE UPDATE
    ON artists
    FOR EACH ROW
EXECUTE FUNCTION fn_set_updated_at();

-- =============================================================================
-- TABLE: albums
-- An album belongs to exactly one artist.
-- =============================================================================
CREATE TABLE albums
(
    album_id     SERIAL PRIMARY KEY,
    title        VARCHAR(200) NOT NULL,
    release_date DATE         NOT NULL,
    artist_id    INTEGER      NOT NULL REFERENCES artists (artist_id) ON DELETE CASCADE
);

COMMENT ON TABLE albums IS 'Music albums, each owned by one artist.';
COMMENT ON COLUMN albums.album_id IS 'Surrogate primary key.';
COMMENT ON COLUMN albums.title IS 'Album title.';
COMMENT ON COLUMN albums.release_date IS 'Official release date.';
COMMENT ON COLUMN albums.artist_id IS 'FK → artists. Mandatory owner.';

-- =============================================================================
-- TABLE: tracks
-- A track belongs to exactly one album.
-- ISRC (International Standard Recording Code) uniquely identifies a recording.
-- =============================================================================
CREATE TABLE tracks
(
    track_id         SERIAL PRIMARY KEY,
    isrc             VARCHAR(12)  NOT NULL UNIQUE,
    title            VARCHAR(200) NOT NULL,
    duration_seconds INTEGER CHECK (duration_seconds > 0),
    album_id         INTEGER      NOT NULL REFERENCES albums (album_id) ON DELETE CASCADE,
    play_count       BIGINT       NOT NULL DEFAULT 0 CHECK (play_count >= 0)
);

COMMENT ON TABLE tracks IS 'Individual audio recordings within an album.';

COMMENT ON COLUMN tracks.track_id IS 'Surrogate primary key.';
COMMENT ON COLUMN tracks.isrc IS 'International Standard Recording Code — globally unique.';
COMMENT ON COLUMN tracks.title IS 'Track title.';
COMMENT ON COLUMN tracks.duration_seconds IS 'Duration in seconds; must be positive.';
COMMENT ON COLUMN tracks.album_id IS 'FK → albums. Mandatory parent.';
COMMENT ON COLUMN tracks.play_count IS 'Cumulative stream/play count. Never decreases.';

-- =============================================================================
-- INDEXES (performance on common FK look-ups)
-- =============================================================================
CREATE INDEX idx_artists_label ON artists (label_id);
CREATE INDEX idx_albums_artist ON albums (artist_id);
CREATE INDEX idx_tracks_album ON tracks (album_id);
CREATE INDEX idx_tracks_isrc ON tracks (isrc);
