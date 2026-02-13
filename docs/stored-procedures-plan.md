# Stored Procedures Plan

## Overview

This document outlines the 5+ stored procedures to implement for data exploitation, meeting course requirements.

## Requirements

- ✅ Nested subqueries (at least 1)
- ✅ GROUP BY ROLLUP (at least 1)
- ✅ PIVOT/crosstab (at least 1)
- ✅ Window functions (optional but recommended)

---

## 1. Revenue by Artist & Month (ROLLUP)

**Procedure Name:** `sp_revenue_rollup()`

**Purpose:** Calculate revenue grouped by artist and month with subtotals and grand total

**SQL:**

```sql
CREATE OR REPLACE FUNCTION sp_revenue_rollup()
RETURNS TABLE(
    artist_name VARCHAR,
    month VARCHAR,
    total_revenue NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(a.stage_name, '*** GRAND TOTAL ***') AS artist_name,
        COALESCE(TO_CHAR(r.log_date, 'YYYY-MM'), 'All Months') AS month,
        SUM(r.amount)::NUMERIC AS total_revenue
    FROM revenue_logs r
    JOIN tracks t ON r.track_id = t.track_id
    JOIN albums al ON t.album_id = al.album_id
    JOIN artists a ON al.artist_id = a.artist_id
    GROUP BY ROLLUP(a.stage_name, TO_CHAR(r.log_date, 'YYYY-MM'))
    ORDER BY a.stage_name NULLS LAST, month NULLS LAST;
END;
$$ LANGUAGE plpgsql;
```

**Usage:**

```sql
SELECT * FROM sp_revenue_rollup();
```

---

## 2. Revenue by Source (PIVOT)

**Procedure Name:** `sp_revenue_pivot()`

**Purpose:** Pivot revenue data to show sources (streaming, download, live) as columns

**SQL:**

```sql
CREATE EXTENSION IF NOT EXISTS tablefunc;

CREATE OR REPLACE FUNCTION sp_revenue_pivot()
RETURNS TABLE(
    artist_name VARCHAR,
    streaming NUMERIC,
    download NUMERIC,
    live NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM crosstab(
        'SELECT a.stage_name, r.source, SUM(r.amount)::NUMERIC
         FROM revenue_logs r
         JOIN tracks t ON r.track_id = t.track_id
         JOIN albums al ON t.album_id = al.album_id
         JOIN artists a ON al.artist_id = a.artist_id
         GROUP BY a.stage_name, r.source
         ORDER BY a.stage_name, r.source',
        'SELECT unnest(ARRAY[''streaming'', ''download'', ''live''])'
    ) AS ct(artist_name VARCHAR, streaming NUMERIC, download NUMERIC, live NUMERIC);
END;
$$ LANGUAGE plpgsql;
```

**Usage:**

```sql
SELECT * FROM sp_revenue_pivot();
```

---

## 3. Top Revenue Artists (Nested Subquery)

**Procedure Name:** `sp_top_artists()`

**Purpose:** Find artists with the highest total revenue using nested subquery in HAVING clause

**SQL:**

```sql
CREATE OR REPLACE FUNCTION sp_top_artists()
RETURNS TABLE(
    artist_name VARCHAR,
    total_revenue NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.stage_name,
        SUM(r.amount)::NUMERIC
    FROM artists a
    JOIN albums al ON a.artist_id = al.artist_id
    JOIN tracks t ON al.album_id = t.album_id
    JOIN revenue_logs r ON t.track_id = r.track_id
    GROUP BY a.artist_id, a.stage_name
    HAVING SUM(r.amount) >= (
        SELECT AVG(sub.total) FROM (
            SELECT SUM(r2.amount) AS total
            FROM revenue_logs r2
            JOIN tracks t2 ON r2.track_id = t2.track_id
            JOIN albums a2 ON t2.album_id = a2.album_id
            GROUP BY a2.artist_id
        ) sub
    )
    ORDER BY total_revenue DESC;
END;
$$ LANGUAGE plpgsql;
```

**Usage:**

```sql
SELECT * FROM sp_top_artists();
```

---

## 4. Contract Revenue Distribution

**Procedure Name:** `sp_contract_splits()`

**Purpose:** Calculate actual revenue distribution based on contract splits

**SQL:**

```sql
CREATE OR REPLACE FUNCTION sp_contract_splits()
RETURNS TABLE(
    contract_id INTEGER,
    artist_name VARCHAR,
    share_percentage NUMERIC,
    total_revenue NUMERIC,
    artist_share NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        cs.contract_id,
        a.stage_name,
        cs.share_percentage,
        COALESCE(SUM(r.amount), 0)::NUMERIC AS total_revenue,
        (COALESCE(SUM(r.amount), 0) * cs.share_percentage / 100)::NUMERIC AS artist_share
    FROM contract_splits cs
    JOIN artists a ON cs.artist_id = a.artist_id
    LEFT JOIN albums al ON a.artist_id = al.artist_id
    LEFT JOIN tracks t ON al.album_id = t.album_id
    LEFT JOIN revenue_logs r ON t.track_id = r.track_id
    GROUP BY cs.contract_id, cs.split_id, a.stage_name, cs.share_percentage
    ORDER BY cs.contract_id, artist_share DESC;
END;
$$ LANGUAGE plpgsql;
```

**Usage:**

```sql
SELECT * FROM sp_contract_splits();
```

---

## 5. Booking Statistics by Venue (Window Function)

**Procedure Name:** `sp_booking_stats()`

**Purpose:** Rank venues by booking count and calculate cumulative bookings

**SQL:**

```sql
CREATE OR REPLACE FUNCTION sp_booking_stats()
RETURNS TABLE(
    venue_name VARCHAR,
    location VARCHAR,
    booking_count BIGINT,
    total_fees NUMERIC,
    venue_rank INTEGER,
    cumulative_bookings BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        v.venue_name,
        v.location,
        COUNT(b.booking_id) AS booking_count,
        COALESCE(SUM(b.fee), 0)::NUMERIC AS total_fees,
        RANK() OVER (ORDER BY COUNT(b.booking_id) DESC)::INTEGER AS venue_rank,
        SUM(COUNT(b.booking_id)) OVER (ORDER BY COUNT(b.booking_id) DESC)::BIGINT AS cumulative_bookings
    FROM venues v
    LEFT JOIN bookings b ON v.venue_id = b.venue_id
    GROUP BY v.venue_id, v.venue_name, v.location
    ORDER BY booking_count DESC;
END;
$$ LANGUAGE plpgsql;
```

**Usage:**

```sql
SELECT * FROM sp_booking_stats();
```

---

## Additional Procedures (Recommended)

### 6. Artist Performance Metrics

- Combine plays, revenue, and bookings
- Calculate averages and percentages

### 7. Monthly Revenue Trend

- Time series analysis
- Month-over-month growth

### 8. Label Performance

- Aggregate artist metrics by label
- Compare label performance

---

## Testing Checklist

- [ ] All procedures return correct results
- [ ] ROLLUP shows subtotals and grand total
- [ ] PIVOT correctly transforms data
- [ ] Nested subquery filters properly
- [ ] Window functions calculate ranks correctly
- [ ] Performance is acceptable (<1s for queries)
- [ ] Procedures handle NULL values
- [ ] Documentation is complete

---

## Integration with Streamlit

Each stored procedure should be called from the Streamlit app:

1. Import `call_stored_procedure()` from `utils.db`
2. Execute procedure and get results as DataFrame
3. Display results in tables or charts
4. Add filters and user interaction
