# Physical Design

## Database Management System

**PostgreSQL 16** (Neon Serverless) with **pgcrypto** extension (`gen_random_uuid()`).

> Neon constraints: no `pgAudit`, no `shared_preload_libraries`, SSL always enforced, SCRAM-SHA-256 authentication.

## Data Types

| Logical Type | Physical Type | Rationale |
|---|---|---|
| Surrogate IDs | `SERIAL` / `BIGSERIAL` | Auto-incrementing PKs; BIGSERIAL for high-volume `revenue_logs` |
| Contract ID | `UUID` DEFAULT `gen_random_uuid()` | Prevents ID guessing; globally unique |
| Names / codes | `VARCHAR(n)` | Variable-length, no padding waste |
| Dates | `DATE` | Calendar date only |
| Timestamps | `TIMESTAMP` | Date + time, no timezone (stored as UTC) |
| Money (revenue) | `NUMERIC(15,4)` | Exact decimal; 4 decimal places for per-stream micro-amounts |
| Money (wallet) | `NUMERIC(15,2)` | 2 decimal places sufficient for VND balances |
| Split ratios | `NUMERIC(5,4)` | Fractions 0–1 with 4-decimal precision |
| ISRC | `VARCHAR(12)` | Fixed-width international recording code |
| Currency | `VARCHAR(3)` | ISO 4217 code, e.g. VND, USD |
| Flexible metadata | `JSONB` | Indexed binary JSON; supports GIN queries |
| Enum states | Custom `ENUM` types | Type safety for status / role / revenue_type fields |
| Play counts | `BIGINT` | Supports billions of streams |

## ENUM Types

```sql
CREATE TYPE artist_role_enum       AS ENUM ('solo', 'band', 'composer', 'producer');
CREATE TYPE event_status_enum      AS ENUM ('SCHEDULED', 'COMPLETED', 'CANCELLED');
CREATE TYPE revenue_type_enum      AS ENUM ('STREAMING', 'SYNC', 'LIVE');
CREATE TYPE withdrawal_status_enum AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'COMPLETED');
```

## Constraints

| Type | Implementation |
|---|---|
| Primary Keys | `SERIAL` / `UUID` per table |
| Foreign Keys | `ON DELETE CASCADE` for child records; `ON DELETE SET NULL` for optional FKs; `ON DELETE RESTRICT` for financial records |
| Check Constraints | Data validation at DB level (ranges, enums, XOR, date ordering) |
| Unique Constraints | `tracks.isrc`, `labels.name`, `artists.stage_name` (via unique index) |
| Not Null | All required fields explicitly marked |
| Append-only | `revenue_logs` — enforced via trigger (`BEFORE UPDATE OR DELETE → RAISE EXCEPTION`) |
| Polymorphic XOR | `contract_splits` uses `beneficiaries` discriminator table (`beneficiary_type IN ('A','L')`) |

## Indexes

```sql
-- Foreign key look-ups
CREATE INDEX idx_artists_label         ON artists          (label_id);
CREATE INDEX idx_albums_artist         ON albums           (artist_id);
CREATE INDEX idx_tracks_album          ON tracks           (album_id);
CREATE INDEX idx_tracks_isrc           ON tracks           (isrc);

-- Revenue queries (high-frequency)
CREATE INDEX idx_revenue_logs_track    ON revenue_logs     (track_id);
CREATE INDEX idx_revenue_logs_date     ON revenue_logs     (log_date);
CREATE INDEX idx_revenue_logs_type     ON revenue_logs     (revenue_type);
CREATE INDEX idx_live_rev_event        ON live_revenue_details (event_id);

-- Contracts
CREATE INDEX idx_contracts_status      ON contracts        (status);
CREATE INDEX idx_contract_splits_contract ON contract_splits (contract_id);
CREATE INDEX idx_contract_splits_track ON contract_splits  (track_id);
CREATE INDEX idx_contract_splits_bene  ON contract_splits  (beneficiary_id);

-- Events
CREATE INDEX idx_events_venue          ON events           (venue_id);
CREATE INDEX idx_events_manager        ON events           (manager_id);
CREATE INDEX idx_events_date           ON events           (event_date);
CREATE INDEX idx_eperformers_event     ON event_performers (event_id);
CREATE INDEX idx_eperformers_artist    ON event_performers (artist_id);

-- Withdrawals
CREATE INDEX idx_withdrawals_artist    ON withdrawals      (artist_id);
CREATE INDEX idx_withdrawals_status    ON withdrawals      (status);

-- GIN indexes for JSONB columns
CREATE INDEX idx_artist_metadata       ON artists          USING GIN (metadata);
CREATE INDEX idx_revenue_raw_data      ON revenue_logs     USING GIN (raw_data);
```

## Views

### v_top_artists (by play count)

```sql
CREATE OR REPLACE VIEW v_top_artists AS
SELECT
    a.artist_id,
    a.stage_name,
    SUM(t.play_count) AS total_plays
FROM artists a
JOIN albums  al ON a.artist_id = al.artist_id
JOIN tracks  t  ON al.album_id  = t.album_id
GROUP BY a.artist_id, a.stage_name
ORDER BY total_plays DESC;
```

### v_top_artists_by_revenue (by revenue)

```sql
CREATE OR REPLACE VIEW v_top_artists_by_revenue AS
SELECT
    a.artist_id,
    a.stage_name,
    SUM(r.amount) AS total_revenue
FROM artists a
JOIN albums      al ON a.artist_id  = al.artist_id
JOIN tracks      t  ON al.album_id  = t.album_id
JOIN revenue_logs r ON t.track_id   = r.track_id
GROUP BY a.artist_id, a.stage_name
ORDER BY total_revenue DESC;
```

### mv_top_artist_cached (Materialized View)

```sql
CREATE MATERIALIZED VIEW mv_top_artist_cached AS
SELECT
    a.artist_id,
    a.stage_name,
    SUM(r.amount)           AS total_revenue,
    COUNT(DISTINCT t.track_id) AS track_count,
    SUM(t.play_count)       AS total_plays
FROM artists a
JOIN albums       al ON a.artist_id = al.artist_id
JOIN tracks       t  ON al.album_id  = t.album_id
LEFT JOIN revenue_logs r ON t.track_id = r.track_id
GROUP BY a.artist_id, a.stage_name
ORDER BY total_revenue DESC;

CREATE INDEX idx_mv_top_artist ON mv_top_artist_cached (artist_id);

-- Refresh manually or via pg_cron (Neon supports pg_cron):
-- REFRESH MATERIALIZED VIEW mv_top_artist_cached;
```

## Triggers

| Trigger | Table | Event | Purpose |
|---|---|---|---|
| `trg_artists_updated_at` | `artists` | BEFORE UPDATE | Auto-set `updated_at = NOW()` |
| `trg_revenue_logs_append_only` | `revenue_logs` | BEFORE UPDATE OR DELETE | Raise exception — enforce append-only |
| `trg_wallet_on_withdrawal` | `withdrawals` | AFTER UPDATE | Deduct `artist_wallets.balance` when status → COMPLETED |

## Security

```sql
-- Application role (read + write, no DDL)
CREATE ROLE artist_revenue_app LOGIN PASSWORD '...';
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO artist_revenue_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO artist_revenue_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO artist_revenue_app;

-- Protect financial records
REVOKE DELETE ON revenue_logs, artist_wallets, withdrawals FROM artist_revenue_app;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM artist_revenue_app;
```

> Neon note: `pgAudit` is not available. Audit trail is handled at the application level via `revenue_logs` (append-only) and `withdrawals` (status history).

## Connection

```
postgresql://user:pass@<host>.neon.tech/neondb?sslmode=require&channel_binding=require
```

SSL is always required. No self-signed certificates. Use `psycopg2-binary` or `asyncpg` with `sslmode=require`.

## Backup

Neon provides automatic continuous backups and point-in-time restore (PITR) up to 7 days on the free tier. No manual `pg_dump` schedule required for primary backup. For local snapshots:

```bash
pg_dump "postgresql://user:pass@host.neon.tech/neondb?sslmode=require" \
    -F c -f backup_$(date +%Y%m%d).dump
```
