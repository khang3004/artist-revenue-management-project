-- =============================================================================
-- V4__Events_and_Venues.sql
-- Migration: Live-event infrastructure
-- Depends on: V1 (artists)
-- Tables: venues, managers, events, event_performers
-- =============================================================================

CREATE TYPE event_status_enum AS ENUM (
    'SCHEDULED', 
    'COMPLETED', 
    'CANCELLED'
);

-- =============================================================================
-- TABLE: venues
-- Physical locations where live events take place.
-- =============================================================================
CREATE TABLE venues (
    venue_id   SERIAL        PRIMARY KEY,
    venue_name VARCHAR(200)  NOT NULL,
    address    VARCHAR(300),
    capacity   INTEGER       CHECK (capacity > 0)
);

COMMENT ON TABLE  venues            IS 'Physical venues that host live events.';
COMMENT ON COLUMN venues.venue_id   IS 'Surrogate primary key.';
COMMENT ON COLUMN venues.venue_name IS 'Name of the venue.';
COMMENT ON COLUMN venues.address    IS 'Full street / postal address.';
COMMENT ON COLUMN venues.capacity   IS 'Maximum audience capacity (must be positive).';

-- =============================================================================
-- TABLE: managers
-- Event/talent managers who coordinate bookings.
-- =============================================================================
CREATE TABLE managers (
    manager_id   SERIAL       PRIMARY KEY,
    manager_name VARCHAR(150) NOT NULL,
    phone_manager VARCHAR(50)
);

COMMENT ON TABLE  managers              IS 'Talent/event managers.';
COMMENT ON COLUMN managers.manager_id   IS 'Surrogate primary key.';
COMMENT ON COLUMN managers.manager_name IS 'Full name of the manager.';
COMMENT ON COLUMN managers.phone_manager IS 'Contact phone number.';

-- =============================================================================
-- TABLE: events
-- A live performance event at a specific venue on a specific date.
-- =============================================================================
CREATE TABLE events (
    event_id   SERIAL        PRIMARY KEY,
    event_name VARCHAR(200)  NOT NULL,
    event_date TIMESTAMP     NOT NULL,
    venue_id   INTEGER       REFERENCES venues   (venue_id)   ON DELETE SET NULL,
    manager_id INTEGER       REFERENCES managers (manager_id) ON DELETE SET NULL,
    status     event_status_enum NOT NULL DEFAULT 'SCHEDULED'
);

COMMENT ON TABLE  events            IS 'Live performance events.';
COMMENT ON COLUMN events.event_id   IS 'Surrogate primary key.';
COMMENT ON COLUMN events.event_name IS 'Descriptive name/title of the event.';
COMMENT ON COLUMN events.event_date IS 'Scheduled date and time of the event.';
COMMENT ON COLUMN events.venue_id   IS 'FK → venues. NULL if venue is TBD.';
COMMENT ON COLUMN events.manager_id IS 'FK → managers. NULL if unassigned.';
COMMENT ON COLUMN events.status     IS 'Event lifecycle: SCHEDULED | COMPLETED | CANCELLED.';

-- =============================================================================
-- TABLE: event_performers (Associative Entity)
-- Many-to-many between events and artists.
-- An event can have multiple performing artists and an artist can
-- appear at multiple events.
-- =============================================================================
CREATE TABLE event_performers (
    event_id           INTEGER NOT NULL REFERENCES events  (event_id)  ON DELETE CASCADE,
    artist_id          INTEGER NOT NULL REFERENCES artists (artist_id) ON DELETE CASCADE,
    performance_fee    NUMERIC(15, 2) CHECK (performance_fee >= 0),
    revenue_share_pct  NUMERIC(5, 4)  CHECK (revenue_share_pct >= 0 AND revenue_share_pct <= 1),
    PRIMARY KEY (event_id, artist_id)
);

COMMENT ON TABLE  event_performers                   IS 'Associative entity: artists performing at events, including financial terms.';
COMMENT ON COLUMN event_performers.event_id          IS 'FK → events.';
COMMENT ON COLUMN event_performers.artist_id         IS 'FK → artists.';
COMMENT ON COLUMN event_performers.performance_fee   IS 'Fixed performance fee / cat-xe.';
COMMENT ON COLUMN event_performers.revenue_share_pct IS 'Percentage share of revenue from ticket sales (0-1).';

-- =============================================================================
-- INDEXES
-- =============================================================================
CREATE INDEX idx_events_venue   ON events          (venue_id);
CREATE INDEX idx_events_manager ON events          (manager_id);
CREATE INDEX idx_events_date    ON events          (event_date);
CREATE INDEX idx_eperfomers_event  ON event_performers (event_id);
CREATE INDEX idx_eperfomers_artist ON event_performers (artist_id);
