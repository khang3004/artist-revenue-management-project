// RevenueLog.swift
// Amplify Core
//
// Domain models for revenue data: raw log entries, aggregated monthly rollups,
// pivot rows, and the top-earner leaderboard — all consumed by the Dashboard.
// Maps tables and aggregate queries from V5__Revenue_and_Wallets.sql.

import Foundation

// MARK: - RevenueType

/// Discriminates the three revenue source categories tracked by the system.
///
/// Mirrors the `revenue_type_enum` PostgreSQL type in `V5__Revenue_and_Wallets.sql`:
/// `ENUM ('STREAMING', 'SYNC', 'LIVE')`.
public enum RevenueType: String, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    case STREAMING
    case SYNC
    case LIVE

    public var id: String { rawValue }

    /// A human-friendly display label suitable for chart legends and badges.
    public var displayName: String {
        switch self {
        case .STREAMING: return "Streaming"
        case .SYNC:      return "Sync & Licensing"
        case .LIVE:      return "Live Performance"
        }
    }

    /// The SF Symbol associated with this revenue category.
    public var symbolName: String {
        switch self {
        case .STREAMING: return "music.note"
        case .SYNC:      return "film.fill"
        case .LIVE:      return "mic"
        }
    }
}

// MARK: - RevenueLog

/// Represents a single revenue event from the `revenue_logs` fact table.
///
/// ### Database Mapping
/// - Primary table: `revenue_logs`
///   - `log_id`       BIGSERIAL PRIMARY KEY
///   - `track_id`     INTEGER (NULLABLE FK → tracks, ON DELETE SET NULL)
///   - `source`       VARCHAR(50) NOT NULL
///   - `amount`       NUMERIC(15,4) NOT NULL (cast to float8 in queries)
///   - `log_date`     TIMESTAMP NOT NULL
///   - `revenue_type` revenue_type_enum NOT NULL (cast to text in queries)
///
/// Conforms to `Identifiable`, `Codable`, `Hashable`, and `Sendable`.
public struct RevenueLog: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// Big-serial surrogate PK. Corresponds to `revenue_logs.log_id`.
    public let id: Int

    /// Associated track FK. `nil` for venue/event-only revenue entries.
    /// Corresponds to `revenue_logs.track_id` (NULLABLE).
    public let trackId: Int?

    /// Name of the originating source platform (e.g., `"Spotify"`, `"Sync - Netflix"`).
    /// Corresponds to `revenue_logs.source`.
    public let source: String

    /// Gross revenue amount for this event. Decoded as `Double` via `::float8` SQL cast.
    /// Corresponds to `revenue_logs.amount`.
    public let amount: Double

    /// Timestamp the revenue event was recorded.
    /// Corresponds to `revenue_logs.log_date`.
    public let logDate: Date

    /// ISA discriminator identifying the revenue category.
    /// Corresponds to `revenue_logs.revenue_type`.
    public let revenueType: RevenueType

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id = "logId"
        case trackId, source, amount, logDate, revenueType
    }

    // MARK: - Memberwise Initialiser

    public init(
        id: Int,
        trackId: Int?,
        source: String,
        amount: Double,
        logDate: Date,
        revenueType: RevenueType
    ) {
        self.id          = id
        self.trackId     = trackId
        self.source      = source
        self.amount      = amount
        self.logDate     = logDate
        self.revenueType = revenueType
    }
}

// MARK: - RevenuePoint

/// A time-aggregated revenue datum produced by the monthly `GROUP BY` rollup query.
///
/// Consumed by SwiftUI `Charts` in `RevenueRollUpView` to render the
/// multi-series `LineMark` + `AreaMark` chart.
///
/// Conforms to `Identifiable`, `Codable`, `Hashable`, and `Sendable`.
public struct RevenuePoint: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// A stable random UUID assigned at construction time to satisfy `Identifiable`.
    public let id: UUID

    /// The calendar month this aggregation represents (first-day-of-month, UTC).
    /// Derived from `DATE_TRUNC('month', log_date)`.
    public let month: Date

    /// Total gross revenue across all events in this month for `revenueType`.
    /// Decoded via `SUM(amount)::float8`.
    public let totalAmount: Double

    /// The revenue category this data point belongs to.
    public let revenueType: RevenueType

    // MARK: - Memberwise Initialiser

    /// Creates a `RevenuePoint` for a specific month and revenue category.
    ///
    /// - Parameters:
    ///   - month:       First-day-of-month Date (from `DATE_TRUNC`).
    ///   - totalAmount: Summed gross revenue for the period.
    ///   - revenueType: Revenue category discriminator.
    public init(month: Date, totalAmount: Double, revenueType: RevenueType) {
        self.id          = UUID()
        self.month       = month
        self.totalAmount = totalAmount
        self.revenueType = revenueType
    }
}

// MARK: - RevenuePivotRow

/// A monthly revenue pivot row containing per-category breakdowns for stacked charts.
///
/// Produced by `RevenueRepository.fetchPivot()` using a `GROUP BY + FILTER` aggregate
/// query. Consumed by the Dashboard's stacked bar / composition charts.
///
/// Conforms to `Identifiable`, `Codable`, `Hashable`, and `Sendable`.
public struct RevenuePivotRow: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// Stable UUID assigned at construction time.
    public let id: UUID

    /// The calendar month this row represents.
    public let month: Date

    /// Gross streaming revenue in this month.
    public let streamingAmount: Double

    /// Gross sync/licensing revenue in this month.
    public let syncAmount: Double

    /// Gross live-performance revenue in this month.
    public let liveAmount: Double

    // MARK: - Computed Properties

    /// The total revenue across all three categories for this month.
    public var totalAmount: Double { streamingAmount + syncAmount + liveAmount }

    // MARK: - Memberwise Initialiser

    public init(month: Date, streamingAmount: Double, syncAmount: Double, liveAmount: Double) {
        self.id              = UUID()
        self.month           = month
        self.streamingAmount = streamingAmount
        self.syncAmount      = syncAmount
        self.liveAmount      = liveAmount
    }
}

// MARK: - TopEarner

/// Represents a ranked top-earning artist produced by the revenue rollup query.
///
/// Displayed in the Dashboard's leaderboard table, ordered by total gross revenue.
///
/// Conforms to `Identifiable`, `Codable`, `Hashable`, and `Sendable`.
public struct TopEarner: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// The artist's primary key (`artists.artist_id`).
    public let id: Int

    /// The artist's stage name (`artists.stage_name`).
    public let stageName: String

    /// Cumulative gross revenue across all revenue streams, joined through albums + tracks.
    /// Decoded via `COALESCE(SUM(amount), 0)::float8`.
    public let totalRevenue: Double

    // MARK: - Computed Properties

    /// Returns the total revenue formatted as a USD currency string.
    public var formattedRevenue: String {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle   = .currency
        formatter.currencyCode  = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalRevenue)) ?? "$0"
    }

    // MARK: - Memberwise Initialiser

    public init(id: Int, stageName: String, totalRevenue: Double) {
        self.id           = id
        self.stageName    = stageName
        self.totalRevenue = totalRevenue
    }
}
