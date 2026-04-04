# Logical Design

## Entity Relationship Model

### Group 1 — Core Entities

#### labels

```
labels(
    label_id:      SERIAL PRIMARY KEY,
    name:          VARCHAR(150) NOT NULL UNIQUE,
    founded_date:  DATE,
    contact_email: VARCHAR(100),
    created_at:    TIMESTAMP NOT NULL DEFAULT NOW()
)
```

#### artists (Parent — ISA overlapping, partial)

```
artists(
    artist_id:  SERIAL PRIMARY KEY,
    stage_name: VARCHAR(100) NOT NULL,
    full_name:  VARCHAR(150),
    debut_date: DATE,
    birthday:   DATE,
    metadata:   JSONB,
    label_id:   INTEGER REFERENCES labels(label_id) ON DELETE SET NULL,
    created_at: TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at: TIMESTAMP NOT NULL DEFAULT NOW()
)
```

#### artist_roles (Junction — overlapping ISA)

```
artist_roles(
    artist_id: INTEGER NOT NULL REFERENCES artists(artist_id) ON DELETE CASCADE,
    role:      artist_role_enum NOT NULL,   -- solo | band | composer | producer
    PRIMARY KEY (artist_id, role)
)
```

#### solo_artists (ISA sub-type)

```
solo_artists(
    artist_id:     INTEGER PRIMARY KEY REFERENCES artists(artist_id) ON DELETE CASCADE,
    vocal_range:   VARCHAR(50),
    talent_agency: VARCHAR(150)
)
```

#### bands (ISA sub-type)

```
bands(
    artist_id:      INTEGER PRIMARY KEY REFERENCES artists(artist_id) ON DELETE CASCADE,
    formation_date: DATE,
    member_count:   INTEGER CHECK (member_count >= 2),
    is_active:      BOOLEAN NOT NULL DEFAULT TRUE
)
```

#### composers (ISA sub-type)

```
composers(
    artist_id:   INTEGER PRIMARY KEY REFERENCES artists(artist_id) ON DELETE CASCADE,
    pen_name:    VARCHAR(100),
    total_works: INTEGER NOT NULL DEFAULT 0 CHECK (total_works >= 0)
)
```

#### producers (ISA sub-type)

```
producers(
    artist_id:        INTEGER PRIMARY KEY REFERENCES artists(artist_id) ON DELETE CASCADE,
    studio_name:      VARCHAR(150),
    production_style: VARCHAR(100)
)
```

#### band_members

```
band_members(
    band_id:            INTEGER NOT NULL REFERENCES bands(artist_id) ON DELETE CASCADE,
    artist_id:          INTEGER NOT NULL REFERENCES artists(artist_id) ON DELETE CASCADE,
    join_date:          DATE,
    leave_date:         DATE,
    internal_split_pct: NUMERIC(5,4) CHECK (internal_split_pct BETWEEN 0 AND 1),
    PRIMARY KEY (band_id, artist_id),
    CHECK (leave_date IS NULL OR leave_date > join_date)
)
```

#### albums

```
albums(
    album_id:     SERIAL PRIMARY KEY,
    title:        VARCHAR(200) NOT NULL,
    release_date: DATE NOT NULL,
    artist_id:    INTEGER NOT NULL REFERENCES artists(artist_id) ON DELETE CASCADE
)
```

#### tracks

```
tracks(
    track_id:         SERIAL PRIMARY KEY,
    isrc:             VARCHAR(12) NOT NULL UNIQUE,
    title:            VARCHAR(200) NOT NULL,
    duration_seconds: INTEGER CHECK (duration_seconds > 0),
    album_id:         INTEGER NOT NULL REFERENCES albums(album_id) ON DELETE CASCADE,
    play_count:       BIGINT NOT NULL DEFAULT 0 CHECK (play_count >= 0)
)
```

---

### Group 2 — Contracts & Splits

#### contracts (Parent — ISA disjoint, total)

```
contracts(
    contract_id:   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name:          VARCHAR(200) NOT NULL,
    start_date:    DATE NOT NULL,
    end_date:      DATE,
    contract_type: VARCHAR(20) NOT NULL CHECK (contract_type IN ('recording','distribution','publishing')),
    status:        VARCHAR(20) NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active','expired','terminated','draft')),
    created_at:    TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (end_date IS NULL OR end_date > start_date)
)
```

#### recording_contracts (ISA sub-type)

```
recording_contracts(
    contract_id:               UUID PRIMARY KEY REFERENCES contracts(contract_id) ON DELETE CASCADE,
    advance_amount:            NUMERIC(15,4) CHECK (advance_amount >= 0),
    album_commitment_quantity: INTEGER CHECK (album_commitment_quantity > 0),
    exclusivity_years:         INTEGER CHECK (exclusivity_years > 0)
)
```

#### distribution_contracts (ISA sub-type)

```
distribution_contracts(
    contract_id:          UUID PRIMARY KEY REFERENCES contracts(contract_id) ON DELETE CASCADE,
    territory:            VARCHAR(100) NOT NULL,
    distribution_fee_pct: NUMERIC(5,4) NOT NULL CHECK (distribution_fee_pct BETWEEN 0 AND 1)
)
```

#### publishing_contracts (ISA sub-type)

```
publishing_contracts(
    contract_id:          UUID PRIMARY KEY REFERENCES contracts(contract_id) ON DELETE CASCADE,
    copyright_owner:      VARCHAR(200),
    sync_rights_included: BOOLEAN NOT NULL DEFAULT FALSE
)
```

#### beneficiaries + sub-types (Polymorphic XOR)

```
beneficiaries(
    beneficiary_id:   SERIAL PRIMARY KEY,
    beneficiary_type: CHAR(1) NOT NULL CHECK (beneficiary_type IN ('A','L'))
)

artist_beneficiaries(
    beneficiary_id: INTEGER PRIMARY KEY REFERENCES beneficiaries(beneficiary_id) ON DELETE CASCADE,
    artist_id:      INTEGER NOT NULL REFERENCES artists(artist_id) ON DELETE CASCADE
)

label_beneficiaries(
    beneficiary_id: INTEGER PRIMARY KEY REFERENCES beneficiaries(beneficiary_id) ON DELETE CASCADE,
    label_id:       INTEGER NOT NULL REFERENCES labels(label_id) ON DELETE CASCADE
)
```

#### contract_splits

```
contract_splits(
    split_id:         SERIAL PRIMARY KEY,
    contract_id:      UUID NOT NULL REFERENCES contracts(contract_id) ON DELETE CASCADE,
    track_id:         INTEGER NOT NULL REFERENCES tracks(track_id) ON DELETE CASCADE,
    beneficiary_id:   INTEGER NOT NULL REFERENCES beneficiaries(beneficiary_id),
    share_percentage: NUMERIC(5,4) NOT NULL CHECK (share_percentage > 0 AND share_percentage <= 1),
    role:             VARCHAR(50) NOT NULL,
    UNIQUE (contract_id, track_id, beneficiary_id)
)
```

---

### Group 3 — Revenue, Wallets, Withdrawals

#### revenue_logs (Parent — ISA disjoint, total)

```
revenue_logs(
    log_id:       BIGSERIAL PRIMARY KEY,
    track_id:     INTEGER REFERENCES tracks(track_id) ON DELETE SET NULL,   -- nullable for Live
    source:       VARCHAR(50) NOT NULL,
    amount:       NUMERIC(15,4) NOT NULL DEFAULT 0 CHECK (amount >= 0),
    currency:     VARCHAR(3) NOT NULL DEFAULT 'VND',
    log_date:     TIMESTAMP NOT NULL DEFAULT NOW(),
    raw_data:     JSONB,
    revenue_type: revenue_type_enum NOT NULL   -- STREAMING | SYNC | LIVE
)
```

#### streaming_revenue_details (ISA sub-type)

```
streaming_revenue_details(
    log_id:          BIGINT PRIMARY KEY REFERENCES revenue_logs(log_id) ON DELETE CASCADE,
    stream_count:    INTEGER NOT NULL CHECK (stream_count >= 0),
    per_stream_rate: NUMERIC(10,6) NOT NULL CHECK (per_stream_rate >= 0),
    platform:        VARCHAR(50) NOT NULL
)
```

#### sync_revenue_details (ISA sub-type)

```
sync_revenue_details(
    log_id:        BIGINT PRIMARY KEY REFERENCES revenue_logs(log_id) ON DELETE CASCADE,
    licensee_name: VARCHAR(200) NOT NULL,
    usage_type:    VARCHAR(50) NOT NULL
)
```

#### live_revenue_details (ISA sub-type)

```
live_revenue_details(
    log_id:      BIGINT PRIMARY KEY REFERENCES revenue_logs(log_id) ON DELETE CASCADE,
    event_id:    INTEGER NOT NULL REFERENCES events(event_id) ON DELETE RESTRICT,
    ticket_sold: INTEGER CHECK (ticket_sold >= 0)
)
```

#### artist_wallets (1:1 with artists)

```
artist_wallets(
    artist_id: INTEGER PRIMARY KEY REFERENCES artists(artist_id) ON DELETE CASCADE,
    balance:   NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (balance >= 0)
)
```

#### withdrawals

```
withdrawals(
    withdrawal_id: SERIAL PRIMARY KEY,
    artist_id:     INTEGER NOT NULL REFERENCES artists(artist_id) ON DELETE RESTRICT,
    amount:        NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    status:        withdrawal_status_enum NOT NULL DEFAULT 'PENDING',
                   -- PENDING | APPROVED | REJECTED | COMPLETED
    requested_at:  TIMESTAMP NOT NULL DEFAULT NOW(),
    processed_at:  TIMESTAMP,
    method:        VARCHAR(50),
    note:          JSONB
)
```

---

### Group 4 — Events & Venues

#### venues

```
venues(
    venue_id:      SERIAL PRIMARY KEY,
    venue_name:    VARCHAR(200) NOT NULL,
    venue_address: VARCHAR(300),
    capacity:      INTEGER CHECK (capacity > 0)
)
```

#### managers

```
managers(
    manager_id:    SERIAL PRIMARY KEY,
    manager_name:  VARCHAR(150) NOT NULL,
    manager_phone: VARCHAR(50)
)
```

#### events

```
events(
    event_id:   SERIAL PRIMARY KEY,
    event_name: VARCHAR(200) NOT NULL,
    event_date: TIMESTAMP NOT NULL,
    venue_id:   INTEGER REFERENCES venues(venue_id) ON DELETE SET NULL,
    manager_id: INTEGER REFERENCES managers(manager_id) ON DELETE SET NULL,
    status:     event_status_enum NOT NULL DEFAULT 'SCHEDULED',
                -- SCHEDULED | COMPLETED | CANCELLED
    notes:      TEXT
)
```

#### event_performers (M:N — artists ↔ events)

```
event_performers(
    event_id:          INTEGER NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    artist_id:         INTEGER NOT NULL REFERENCES artists(artist_id) ON DELETE CASCADE,
    performance_fee:   NUMERIC(15,2) CHECK (performance_fee >= 0),
    revenue_share_pct: NUMERIC(5,4) CHECK (revenue_share_pct BETWEEN 0 AND 1),
    PRIMARY KEY (event_id, artist_id)
)
```

---

## Normalization

All tables are in **3NF (Third Normal Form)**:

- No partial dependencies
- No transitive dependencies
- All non-key attributes depend only on the primary key

ISA sub-type tables use PK = FK to the parent, which enforces 1:1 and avoids NULL-heavy wide tables.

## ISA Relationship Details

| ISA | Type | Sub-types |
|---|---|---|
| artists | overlapping, partial | solo_artists, bands, composers, producers |
| contracts | disjoint, total | recording_contracts, distribution_contracts, publishing_contracts |
| revenue_logs | disjoint, total | streaming_revenue_details, sync_revenue_details, live_revenue_details |

**overlapping, partial** (artists): an artist can have multiple roles (e.g. solo + composer) or none (e.g. an unclassified DJ). Implemented via `artist_roles` junction table + separate sub-type tables for role-specific attributes.

**disjoint, total** (contracts, revenue): every row in the parent must exist in exactly one sub-type table. Enforced by `contract_type` / `revenue_type` discriminator columns and NOT NULL FK in sub-types.

## Indexes for Performance

```sql
-- FK look-ups
CREATE INDEX idx_artists_label      ON artists (label_id);
CREATE INDEX idx_albums_artist      ON albums  (artist_id);
CREATE INDEX idx_tracks_album       ON tracks  (album_id);
CREATE INDEX idx_tracks_isrc        ON tracks  (isrc);

-- Revenue queries
CREATE INDEX idx_revenue_logs_track ON revenue_logs (track_id);
CREATE INDEX idx_revenue_logs_date  ON revenue_logs (log_date);
CREATE INDEX idx_revenue_logs_type  ON revenue_logs (revenue_type);

-- Events
CREATE INDEX idx_events_venue       ON events (venue_id);
CREATE INDEX idx_events_manager     ON events (manager_id);
CREATE INDEX idx_events_date        ON events (event_date);

-- Contracts
CREATE INDEX idx_contracts_status   ON contracts (status);

-- JSONB (GIN)
CREATE INDEX idx_artist_metadata    ON artists      USING GIN (metadata);
CREATE INDEX idx_revenue_raw_data   ON revenue_logs USING GIN (raw_data);
```
