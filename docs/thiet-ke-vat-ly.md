# Physical Design

## Database Management System

**PostgreSQL 16** with **pgvector** extension

## Implementation Details

### Storage

```sql
-- Tablespace configuration (if needed)
-- CREATE TABLESPACE artist_revenue_data LOCATION '/var/lib/postgresql/data';
```

### Data Types Selection

| Logical Type  | Physical Type  | Rationale                          |
| ------------- | -------------- | ---------------------------------- |
| ID fields     | SERIAL/INTEGER | Auto-incrementing primary keys     |
| Names         | VARCHAR        | Variable length, efficient storage |
| Dates         | DATE           | Standard date storage              |
| Timestamps    | TIMESTAMP      | Includes time component            |
| Money         | DECIMAL(12, 2) | Precise decimal arithmetic         |
| JSON data     | JSONB          | Indexed JSON with compression      |
| Large numbers | BIGINT         | For play counts                    |

### Constraints Implementation

1. **Primary Keys**: SERIAL with AUTO_INCREMENT
2. **Foreign Keys**: ON DELETE CASCADE/RESTRICT based on business rules
3. **CHECK Constraints**: Data validation at database level
4. **UNIQUE Constraints**: Prevent duplicate data
5. **NOT NULL**: Enforce required fields

### Indexes

```sql
-- B-tree indexes for foreign keys
CREATE INDEX idx_albums_artist ON albums(artist_id);
CREATE INDEX idx_tracks_album ON tracks(album_id);
CREATE INDEX idx_revenue_track ON revenue_logs(track_id);

-- Date range queries
CREATE INDEX idx_revenue_date ON revenue_logs(log_date);
CREATE INDEX idx_bookings_date ON bookings(event_date);

-- GIN index for JSONB columns
CREATE INDEX idx_revenue_raw_data ON revenue_logs USING GIN(raw_data);
CREATE INDEX idx_artist_metadata ON artists USING GIN(metadata);
```

### Views

#### v_top_artists (Regular View)

```sql
CREATE OR REPLACE VIEW v_top_artists AS
SELECT
    a.artist_id,
    a.stage_name,
    SUM(t.play_count) as total_plays
FROM artists a
JOIN albums al ON a.artist_id = al.artist_id
JOIN tracks t ON al.album_id = t.album_id
GROUP BY a.artist_id, a.stage_name
ORDER BY total_plays DESC;
```

#### v_top_artists2 (By Revenue)

```sql
CREATE OR REPLACE VIEW v_top_artists2 AS
SELECT
    a.artist_id,
    a.stage_name,
    SUM(r.amount) as total_revenue
FROM artists a
JOIN albums al ON a.artist_id = al.artist_id
JOIN tracks t ON al.album_id = t.album_id
JOIN revenue_logs r ON t.track_id = r.track_id
GROUP BY a.artist_id, a.stage_name
ORDER BY total_revenue DESC;
```

#### mv_top_artist_cached (Materialized View)

```sql
CREATE MATERIALIZED VIEW mv_top_artist_cached AS
SELECT
    a.artist_id,
    a.stage_name,
    SUM(r.amount) as total_revenue,
    COUNT(DISTINCT t.track_id) as track_count,
    SUM(t.play_count) as total_plays
FROM artists a
JOIN albums al ON a.artist_id = al.artist_id
JOIN tracks t ON al.album_id = t.album_id
LEFT JOIN revenue_logs r ON t.track_id = r.track_id
GROUP BY a.artist_id, a.stage_name
ORDER BY total_revenue DESC;

-- Create index on materialized view
CREATE INDEX idx_mv_top_artist ON mv_top_artist_cached(artist_id);

-- Refresh strategy (schedule with cron or pg_cron)
-- REFRESH MATERIALIZED VIEW mv_top_artist_cached;
```

### Security

```sql
-- Create application user
CREATE USER artist_revenue_app WITH PASSWORD 'secure_password';

-- Grant specific permissions
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO artist_revenue_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO artist_revenue_app;

-- Revoke dangerous permissions
REVOKE DELETE ON contracts FROM artist_revenue_app;
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM artist_revenue_app;
```

### Backup Strategy

1. **Daily full backups**: pg_dump
2. **WAL archiving**: Continuous backup
3. **Retention**: 30 days

```bash
# Daily backup script
pg_dump -U postgres -d artist_revenue_db -F c -f backup_$(date +%Y%m%d).dump
```

### Performance Tuning

```sql
-- Configuration recommendations
-- shared_buffers = 256MB
-- effective_cache_size = 1GB
-- maintenance_work_mem = 64MB
-- checkpoint_completion_target = 0.9
-- wal_buffers = 16MB
-- default_statistics_target = 100
-- random_page_cost = 1.1  -- For SSD
-- effective_io_concurrency = 200
```

## Docker Configuration

See `docker-compose.yml` for:

- PostgreSQL container setup
- Volume mounting for persistence
- Network configuration
- Health checks
- pgAdmin integration
