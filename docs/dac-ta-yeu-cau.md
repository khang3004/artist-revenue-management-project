# Data Requirements Specification

## System Overview

Artist Revenue Management System manages music artists, their works, and revenue from multiple sources.

## Main Entities

### 1. Artists

- Artist ID (PK)
- Stage name (NOT NULL)
- Full name
- Debut date
- Birthday
- Metadata (social media links, JSONB)
- Label ID (FK → labels, nullable — independent artists have no label)
- Created at, Updated at

**Specialization (ISA — overlapping, partial):**
An artist can hold multiple roles simultaneously or none (e.g. an unclassified producer/DJ).

- **Solo Artists**: vocal_range, talent_agency
- **Bands**: formation_date, member_count (CHECK ≥ 2), is_active
- **Composers**: pen_name, total_works (CHECK ≥ 0)

### 2. Labels (Record Labels)

- Label ID (PK)
- Label name (UNIQUE, NOT NULL)
- Founded date
- Contact email
- Created at

### 3. Albums

- Album ID (PK)
- Album title (NOT NULL)
- Release date (NOT NULL)
- Artist ID (FK → artists, NOT NULL)

### 4. Tracks

- Track ID (PK)
- Track title (NOT NULL)
- Duration seconds (INT, CHECK > 0)
- Album ID (FK → albums, NOT NULL)
- Play count (BIGINT, DEFAULT 0, CHECK ≥ 0)
- ISRC (VARCHAR(12), UNIQUE, NOT NULL)

### 5. Revenue Logs

- Log ID (PK, BIGSERIAL)
- Track ID (FK → tracks, nullable for Live revenue covering a full show)
- Source (platform/system name)
- Amount (DECIMAL(15,4), CHECK ≥ 0)
- Currency (VARCHAR(3), DEFAULT 'VND')
- Log date (TIMESTAMP)
- Raw data (JSONB — original payload for audit/reconciliation)

**Specialization (ISA — disjoint, total):**

- **Streaming**: stream_count, per_stream_rate, platform (e.g. Spotify, Apple Music, Zing MP3)
- **Sync**: licensee_name, usage_type (e.g. Film, TV, Advertisement, Game)
- **Live**: event_id (FK → events, NOT NULL), tickets_sold

### 6. Contracts

- Contract ID (PK, UUID via gen_random_uuid())
- Name (NOT NULL)
- Start date (NOT NULL)
- End date (CHECK end_date > start_date; nullable = open-ended)
- Contract type: recording / distribution / publishing
- Status: active / expired / terminated / draft
- Created at

**Specialization (ISA — disjoint, total):**

- **Recording**: advance_amount (DECIMAL), album_commitment_quantity (INT), exclusivity_years (INT)
- **Distribution**: territory (VARCHAR, e.g. 'Global', 'Southeast Asia'), distribution_fee_pct (DECIMAL(5,2), CHECK 0–100)
- **Publishing**: copyright_holder (VARCHAR), sync_rights (BOOLEAN)

### 7. Contract Splits

- Split ID (PK)
- Contract ID (FK → contracts, NOT NULL)
- Track ID (FK → tracks, NOT NULL)
- Beneficiary: artist_id (FK → artists) XOR label_id (FK → labels) — exactly one NOT NULL
- Share percentage (DECIMAL(5,4), CHECK 0–1)
- Role (VARCHAR, e.g. performer, composer, producer, label)

Business rule: total share_percentage per (contract_id, track_id) must not exceed 1.0.

### 8. Artist Wallets

- Artist ID (PK + FK → artists, 1:1)
- Balance (DECIMAL(15,2), CHECK ≥ 0)

### 9. Withdrawals

- Withdrawal ID (PK)
- Artist ID (FK → artists, NOT NULL)
- Amount (DECIMAL(15,2), CHECK > 0)
- Status: pending / approved / rejected / completed
- Requested at (TIMESTAMP)
- Processed at (TIMESTAMP, nullable)
- Method: bank_transfer / momo / zalopay
- Notes (TEXT)

Balance only decreases when a withdrawal status transitions to 'completed'.

### 10. Events

- Event ID (PK)
- Event name (NOT NULL)
- Event date (TIMESTAMP, NOT NULL)
- Venue ID (FK → venues)
- Manager ID (FK → managers)
- Status: SCHEDULED / COMPLETED / CANCELLED
- Notes (TEXT)

**event_performers** (M:N associative entity — artists ↔ events):
- Event ID (FK) + Artist ID (FK) — composite PK
- Performance fee (DECIMAL(15,2))
- Revenue share pct (DECIMAL(5,4), 0–1)

### 11. Venues

- Venue ID (PK)
- Venue name (NOT NULL)
- Venue address
- Capacity (INT, CHECK > 0)

### 12. Managers

- Manager ID (PK)
- Manager name (NOT NULL)
- Manager phone

## Relationships

| Relationship | Cardinality | Description |
|---|---|---|
| labels → artists | 1:N (optional) | Label manages many artists; artists can be independent |
| artists → albums | 1:N | Artist releases many albums |
| albums → tracks | 1:N | Album contains many tracks |
| tracks → revenue_logs | 1:N (nullable FK) | Track generates many revenue events; track_id NULL for live |
| contracts ↔ artists/labels (via splits) | M:N | Contract distributes revenue to multiple beneficiaries |
| artists ↔ events (via event_performers) | M:N | Artist performs at many events; event has many performers |
| venues → events | 1:N | Venue hosts many events |
| managers → events | 1:N | Manager coordinates many events |
| events → revenue_live | 1:N | Event generates many live revenue logs |
| artists → withdrawals | 1:N | Artist makes many withdrawal requests |
| artists → artist_wallets | 1:1 | Each artist has exactly one wallet |
| artists ISA → solo_artists / bands / composers | overlapping, partial | Artist can hold multiple roles or none |
| contracts ISA → recording / distribution / publishing | disjoint, total | Contract belongs to exactly one type |
| revenue_logs ISA → streaming / sync / live | disjoint, total | Revenue event belongs to exactly one source |

## Business Rules

1. Total `share_percentage` of all splits per `(contract_id, track_id)` must not exceed 1.0 (100%)
2. `artist_wallets.balance` only decreases when a `withdrawals.status` transitions to `'completed'`
3. `revenue_logs` is append-only — no UPDATE or DELETE; corrections use a new reversal entry with negative amount
4. Artists can be solo, band, and/or composer simultaneously (overlapping ISA — not disjoint)
5. Every contract must belong to exactly one sub-type: recording, distribution, or publishing (disjoint, total)
6. Live revenue (`revenue_live`) must always link to a valid `event_id` (NOT NULL)
7. Track `duration_seconds` must be positive (> 0)
8. `bands.member_count` must be ≥ 2

## Data Volume Estimates

- Artists: ~10–50
- Albums: ~50–200
- Tracks: ~200–1000
- Revenue Logs: ~1000–10000
- Contracts: ~10–50
- Events: ~20–100
