# Logical Design

## Entity Relationship Model

### Core Entities

#### Artists (Parent Entity)

```
artists(
    artist_id: SERIAL PRIMARY KEY,
    stage_name: VARCHAR(100) NOT NULL,
    full_name: VARCHAR(150) NOT NULL,
    debut_date: DATE,
    metadata: JSONB,
    label_id: INTEGER FOREIGN KEY REFERENCES labels(label_id)
)
```

#### Solo Artists (Child Entity - ISA)

```
solo_artists(
    artist_id: INTEGER PRIMARY KEY FOREIGN KEY REFERENCES artists(artist_id),
    instrument: VARCHAR(50),
    solo_style: VARCHAR(50)
)
```

#### Bands (Child Entity - ISA)

```
bands(
    artist_id: INTEGER PRIMARY KEY FOREIGN KEY REFERENCES artists(artist_id),
    member_count: INTEGER CHECK (member_count > 0),
    formation_date: DATE
)
```

#### Labels

```
labels(
    label_id: SERIAL PRIMARY KEY,
    label_name: VARCHAR(100) NOT NULL UNIQUE,
    country: VARCHAR(50),
    founded_date: DATE
)
```

#### Albums

```
albums(
    album_id: SERIAL PRIMARY KEY,
    album_title: VARCHAR(200) NOT NULL,
    release_date: DATE,
    artist_id: INTEGER NOT NULL FOREIGN KEY REFERENCES artists(artist_id),
    genre: VARCHAR(50)
)
```

#### Tracks

```
tracks(
    track_id: SERIAL PRIMARY KEY,
    track_title: VARCHAR(200) NOT NULL,
    duration: INTEGER CHECK (duration > 0),
    album_id: INTEGER FOREIGN KEY REFERENCES albums(album_id),
    play_count: BIGINT DEFAULT 0,
    isrc: VARCHAR(12) UNIQUE
)
```

### Revenue & Contracts

#### Revenue Logs

```
revenue_logs(
    log_id: SERIAL PRIMARY KEY,
    track_id: INTEGER NOT NULL FOREIGN KEY REFERENCES tracks(track_id),
    source: VARCHAR(20) CHECK (source IN ('streaming', 'download', 'live')),
    amount: DECIMAL(12, 2) NOT NULL CHECK (amount >= 0),
    log_date: DATE NOT NULL,
    raw_data: JSONB
)
```

#### Contracts

```
contracts(
    contract_id: SERIAL PRIMARY KEY,
    contract_type: VARCHAR(50) NOT NULL,
    start_date: DATE NOT NULL,
    end_date: DATE,
    terms: JSONB,
    CHECK (end_date IS NULL OR end_date > start_date)
)
```

#### Contract Splits

```
contract_splits(
    split_id: SERIAL PRIMARY KEY,
    contract_id: INTEGER NOT NULL FOREIGN KEY REFERENCES contracts(contract_id),
    artist_id: INTEGER NOT NULL FOREIGN KEY REFERENCES artists(artist_id),
    share_percentage: DECIMAL(5, 2) NOT NULL CHECK (share_percentage > 0 AND share_percentage <= 100),
    UNIQUE(contract_id, artist_id)
)
```

#### Artist Wallets

```
artist_wallets(
    wallet_id: SERIAL PRIMARY KEY,
    artist_id: INTEGER NOT NULL UNIQUE FOREIGN KEY REFERENCES artists(artist_id),
    balance: DECIMAL(12, 2) DEFAULT 0 CHECK (balance >= 0),
    last_updated: TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
```

### Booking & Venues

#### Bookings

```
bookings(
    booking_id: SERIAL PRIMARY KEY,
    artist_id: INTEGER NOT NULL FOREIGN KEY REFERENCES artists(artist_id),
    venue_id: INTEGER NOT NULL FOREIGN KEY REFERENCES venues(venue_id),
    manager_id: INTEGER FOREIGN KEY REFERENCES managers(manager_id),
    event_date: DATE NOT NULL,
    fee: DECIMAL(12, 2) CHECK (fee >= 0)
)
```

#### Venues

```
venues(
    venue_id: SERIAL PRIMARY KEY,
    venue_name: VARCHAR(100) NOT NULL,
    location: VARCHAR(200),
    capacity: INTEGER CHECK (capacity > 0)
)
```

#### Managers

```
managers(
    manager_id: SERIAL PRIMARY KEY,
    manager_name: VARCHAR(100) NOT NULL,
    contact_info: VARCHAR(200)
)
```

## Normalization

All tables are in **3NF (Third Normal Form)**:

- No partial dependencies
- No transitive dependencies
- All non-key attributes depend only on the primary key

## ISA Relationship Details

**Constraint Type:** Disjoint, Total

- An artist MUST be either a solo artist OR a band
- An artist CANNOT be both simultaneously
- Implementation: Check that artist_id exists in exactly one child table

## Indexes for Performance

```sql
CREATE INDEX idx_albums_artist ON albums(artist_id);
CREATE INDEX idx_tracks_album ON tracks(album_id);
CREATE INDEX idx_revenue_track ON revenue_logs(track_id);
CREATE INDEX idx_revenue_date ON revenue_logs(log_date);
CREATE INDEX idx_bookings_artist ON bookings(artist_id);
CREATE INDEX idx_bookings_date ON bookings(event_date);
```
