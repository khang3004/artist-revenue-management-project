// RevenueRepository.swift
// Amplify Core
//
// Data-access layer for the `revenue_logs` fact table and its ISA sub-type tables.
// Implements monthly rollup, pivot, top-earner, and wallet-summary queries —
// conceptually equivalent to sp1, sp2, sp3, and sp6 stored procedures.

import Foundation
import PostgresNIO
import Logging

/// Repository responsible for all analytical queries against the revenue fact table
/// and `artist_wallets`.
///
/// ### Key Design Decisions
/// - All `NUMERIC` columns are cast to `::float8` in SQL so PostgresNIO can decode
///   them directly as Swift `Double` values (avoiding OID-mismatch errors).
/// - All PostgreSQL `ENUM` columns are cast to `::text` to permit `String` decoding,
///   after which Swift enum initialisers validate the raw value.
/// - The monthly rollup uses `DATE_TRUNC('month', log_date)` which PostgresNIO
///   decodes as a `Date` set to the first instant of each calendar month (UTC).
///
/// Conforms to `Sendable` — all stored properties are immutable actor references or loggers.
public final class RevenueRepository: Sendable {

    // MARK: - Private Properties

    private let client: DatabaseClient
    private let logger: Logger

    // MARK: - Initialiser

    /// Creates a `RevenueRepository` bound to the given `DatabaseClient`.
    ///
    /// - Parameter client: The shared database connection pool actor.
    public init(client: DatabaseClient) {
        self.client = client
        self.logger = Logger(label: "com.labelmaster.repository.revenue")
    }

    // MARK: - Monthly Revenue Rollup

    /// Retrieves monthly gross revenue broken down by `revenue_type` for the
    /// trailing `months` calendar months — equivalent to `sp1_revenue_by_artist_rollup`.
    ///
    /// Each returned `RevenuePoint` represents one `(month, revenueType)` combination.
    /// The Dashboard chart plots three series (Streaming, Sync, Live) from this result.
    ///
    /// - Parameter months: The number of trailing calendar months to include. Pass `nil` for all-time.
    /// - Returns: An array of `RevenuePoint` values ordered chronologically.
    /// - Throws:  `DatabaseError` on connection or decode failure.
    public func fetchMonthlyRollup(months: Int? = 12) async throws -> [RevenuePoint] {
        let sql: PostgresQuery
        if let months {
            sql = """
                SELECT DATE_TRUNC('month', log_date)    AS month,
                       SUM(amount)::float8              AS total_amount,
                       revenue_type::text               AS revenue_type
                FROM   revenue_logs
                WHERE  log_date >= CURRENT_DATE - (\(months) * INTERVAL '1 month')
                GROUP  BY DATE_TRUNC('month', log_date), revenue_type
                ORDER  BY month ASC
                """
        } else {
            sql = """
                SELECT DATE_TRUNC('month', log_date)    AS month,
                       SUM(amount)::float8              AS total_amount,
                       revenue_type::text               AS revenue_type
                FROM   revenue_logs
                GROUP  BY DATE_TRUNC('month', log_date), revenue_type
                ORDER  BY month ASC
                """
        }

        return try await client.query(sql) { row in
            let (month, totalAmount, revenueTypeStr) =
                try row.decode((Date, Double, String).self, context: .default)

            guard let revenueType: RevenueType = RevenueType(rawValue: revenueTypeStr) else {
                throw DatabaseError.decodingFailed(
                    "Unrecognised revenue_type value: '\(revenueTypeStr)'"
                )
            }
            return RevenuePoint(month: month, totalAmount: totalAmount, revenueType: revenueType)
        }
    }

    // MARK: - Revenue Pivot by Source

    /// Retrieves a monthly revenue pivot with per-category column sums for the
    /// trailing 12 months — equivalent to `sp2_revenue_pivot_by_source`.
    ///
    /// Uses a `FILTER (WHERE revenue_type = ...)` aggregate to produce three columns
    /// in a single pass, avoiding multiple sub-queries.
    ///
    /// - Parameter months: The number of trailing calendar months to include. Pass `nil` for all-time.
    /// - Returns: An array of `RevenuePivotRow` values ordered chronologically.
    /// - Throws:  `DatabaseError` on query failure.
    public func fetchPivot(months: Int? = 12) async throws -> [RevenuePivotRow] {
        let sql: PostgresQuery
        if let months {
            sql = """
                SELECT DATE_TRUNC('month', log_date)                                              AS month,
                       COALESCE(SUM(amount) FILTER (WHERE revenue_type = 'STREAMING'), 0)::float8 AS streaming_amt,
                       COALESCE(SUM(amount) FILTER (WHERE revenue_type = 'SYNC'), 0)::float8      AS sync_amt,
                       COALESCE(SUM(amount) FILTER (WHERE revenue_type = 'LIVE'), 0)::float8      AS live_amt
                FROM   revenue_logs
                WHERE  log_date >= CURRENT_DATE - (\(months) * INTERVAL '1 month')
                GROUP  BY DATE_TRUNC('month', log_date)
                ORDER  BY month ASC
                """
        } else {
            sql = """
                SELECT DATE_TRUNC('month', log_date)                                              AS month,
                       COALESCE(SUM(amount) FILTER (WHERE revenue_type = 'STREAMING'), 0)::float8 AS streaming_amt,
                       COALESCE(SUM(amount) FILTER (WHERE revenue_type = 'SYNC'), 0)::float8      AS sync_amt,
                       COALESCE(SUM(amount) FILTER (WHERE revenue_type = 'LIVE'), 0)::float8      AS live_amt
                FROM   revenue_logs
                GROUP  BY DATE_TRUNC('month', log_date)
                ORDER  BY month ASC
                """
        }

        return try await client.query(sql) { row in
            let (month, streamingAmt, syncAmt, liveAmt) =
                try row.decode((Date, Double, Double, Double).self, context: .default)
            return RevenuePivotRow(
                month:           month,
                streamingAmount: streamingAmt,
                syncAmount:      syncAmt,
                liveAmount:      liveAmt
            )
        }
    }

    // MARK: - Top Earning Artists

    /// Retrieves the top `limit` earning artists ranked by cumulative gross revenue
    /// across all revenue streams — equivalent to `sp3_top_earning_artists`.
    ///
    /// Revenue is attributed to artists through the join chain:
    /// `artists → albums → tracks → revenue_logs`.
    /// Artists with no revenue history are included with a `totalRevenue` of `0.0`.
    ///
    /// - Parameter limit: Maximum number of artists to return. Defaults to `10`.
    /// - Returns: An array of `TopEarner` values ordered by descending total revenue.
    /// - Throws:  `DatabaseError` on query failure.
    public func fetchTopEarners(limit: Int = 10) async throws -> [TopEarner] {
        let sql: PostgresQuery = """
            SELECT a.artist_id,
                   a.stage_name,
                   COALESCE(SUM(rl.amount), 0)::float8 AS total_revenue
            FROM   artists a
            LEFT  JOIN albums       al ON al.artist_id  = a.artist_id
            LEFT  JOIN tracks        t ON  t.album_id   = al.album_id
            LEFT  JOIN revenue_logs rl ON rl.track_id   = t.track_id
            GROUP  BY a.artist_id, a.stage_name
            ORDER  BY total_revenue DESC
            LIMIT  \(limit)
            """

        return try await client.query(sql) { row in
            let (id, stageName, totalRevenue) =
                try row.decode((Int, String, Double).self, context: .default)
            return TopEarner(id: id, stageName: stageName, totalRevenue: totalRevenue)
        }
    }

    // MARK: - Artist Wallets

    /// Retrieves all artist wallet balances ordered by descending balance —
    /// equivalent to part of `sp6_wallet_audit_report`.
    ///
    /// Joins `artist_wallets` with `artists` to include the stage name for display.
    ///
    /// - Returns: An array of `ArtistWallet` values ordered by descending balance.
    /// - Throws:  `DatabaseError` on query failure.
    public func fetchWallets() async throws -> [ArtistWallet] {
        let sql: PostgresQuery = """
            SELECT aw.artist_id,
                   a.stage_name,
                   aw.balance::float8
            FROM   artist_wallets aw
            JOIN   artists a ON a.artist_id = aw.artist_id
            ORDER  BY aw.balance DESC
            """

        return try await client.query(sql) { row in
            let (artistId, stageName, balance) =
                try row.decode((Int, String, Double).self, context: .default)
            return ArtistWallet(id: artistId, stageName: stageName, balance: balance)
        }
    }
}
