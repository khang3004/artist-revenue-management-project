# Data Requirements Specification

## System Overview

Artist Revenue Management System manages music artists, their works, and revenue from multiple sources.

## Main Entities

### 1. Artists

- Artist ID (PK)
- Stage name
- Full name
- Debut date
- Metadata (social media links)
- Label ID (FK)

**Specialization (ISA):**

- **Solo Artists**: instrument, solo style
- **Bands**: member count, formation date

### 2. Labels (Record Labels)

- Label ID (PK)
- Label name
- Country
- Founded date

### 3. Albums

- Album ID (PK)
- Album title
- Release date
- Artist ID (FK)
- Genre

### 4. Tracks

- Track ID (PK)
- Track title
- Duration (seconds)
- Album ID (FK)
- Play count
- ISRC (International Standard Recording Code)

### 5. Revenue Logs

- Log ID (PK)
- Track ID (FK)
- Source (streaming/download/live)
- Amount
- Log date
- Raw data (JSONB)

### 6. Contracts

- Contract ID (PK)
- Contract type
- Start date
- End date
- Terms (JSONB)

### 7. Contract Splits

- Split ID (PK)
- Contract ID (FK)
- Artist ID (FK)
- Share percentage

### 8. Artist Wallets

- Wallet ID (PK)
- Artist ID (FK)
- Balance
- Last updated

### 9. Bookings

- Booking ID (PK)
- Artist ID (FK)
- Venue ID (FK)
- Manager ID (FK)
- Event date
- Fee

### 10. Venues

- Venue ID (PK)
- Venue name
- Location
- Capacity

### 11. Managers

- Manager ID (PK)
- Manager name
- Contact info

## Relationships

1. Labels → Artists (1:N)
2. Artists → Albums (1:N)
3. Albums → Tracks (1:N)
4. Tracks → Revenue Logs (1:N)
5. Contracts ↔ Artists (M:N via Contract Splits)
6. Artists → Bookings (1:N)
7. Venues → Bookings (1:N)
8. Managers → Bookings (1:N)
9. Artists → ISA → {Solo Artists, Bands} (disjoint, total)

## Business Rules

1. Each artist must belong to exactly one label
2. Albums must have at least one track
3. Revenue splits must sum to 100% for each contract
4. Artists can be either solo artists OR bands (not both)
5. Bookings must have future event dates
6. Track duration must be positive
7. Play count starts at 0 and can only increase

## Data Volume Estimates

- Artists: ~10-50
- Albums: ~50-200
- Tracks: ~200-1000
- Revenue Logs: ~1000-10000
- Contracts: ~10-50
- Bookings: ~20-100
