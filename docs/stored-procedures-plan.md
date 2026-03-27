# Stored Procedures

> Authoritative SQL source: `db/procedures/sp.sql`

## Summary

| # | Function | Params | Key Technique | Key Tables |
|---|---|---|---|---|
| SP1 | `sp_revenue_by_artist_rollup` | `p_year`, `p_currency` | GROUP BY ROLLUP + GROUPING() | revenue_logs, tracks, albums, artists |
| SP2 | `sp_revenue_pivot_by_source` | `p_year` | crosstab (tablefunc) + CTE UNION ALL | revenue_logs + ISA detail tables |
| SP2v | `sp_revenue_pivot_by_source_v2` | `p_year` | SUM FILTER (conditional aggregation / PIVOT alternative) | revenue_logs + ISA detail tables |
| SP3 | `sp_top_earning_artists` | `p_year` | Nested subquery (2-level) in HAVING | artists, albums, tracks, revenue_logs |
| SP4 | `sp_contract_revenue_distribution` | `p_contract_id UUID` | LATERAL JOIN + polymorphic beneficiary (beneficiaries ISA) | contracts, contract_splits, beneficiaries, tracks, revenue_logs |
| SP5 | `sp_top_tracks_per_artist` | `p_top_n`, `p_year` | CTE + RANK() OVER (PARTITION BY) window function | artists, albums, tracks, revenue_logs |
| SP6 | `sp_wallet_audit_report` | — | Multi-subquery + JSONB ->> + CASE reconciliation | artists, artist_wallets, withdrawals, contract_splits, revenue_logs |
| SP7 | `sp_venue_event_analytics` | `p_year` | CTE + ROLLUP + DENSE_RANK() window | events, event_performers, venues, artists, live_revenue_details, revenue_logs |
| SP8 | `sp_search_artists` | `p_genre`, `p_name` | GIN index + JSONB @> operator + ILIKE | artists, labels, tracks, albums |
| — | `sp_refresh_all_mv` (PROCEDURE) | — | REFRESH MATERIALIZED VIEW CONCURRENTLY | Materialized views |

## Course Requirements Coverage

| Requirement | Covered by |
|---|---|
| GROUP BY ROLLUP | SP1, SP7 |
| PIVOT / crosstab | SP2 (crosstab), SP2v (FILTER) |
| Nested subquery in HAVING | SP3 |
| LATERAL JOIN | SP4 |
| CTE | SP2, SP5, SP6 (inline subqueries), SP7 |
| Window functions (RANK, DENSE_RANK) | SP5, SP7 |
| JSONB operators (GIN, @>, ->>) | SP6, SP8 |
