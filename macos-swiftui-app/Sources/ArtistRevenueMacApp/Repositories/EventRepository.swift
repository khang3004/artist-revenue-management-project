// EventRepository.swift
// Amplify Core
//
// Data-access layer for events, venues, and performer analytics.
// Wraps sp_venue_event_analytics (SP7) defined in sp7_venue_event_analytics.sql.

import Foundation
import PostgresNIO
import Logging

// MARK: - VenueEventRow

/// One aggregated row returned by `sp_venue_event_analytics(year)`.
///
/// Includes ROLLUP rows where `venueName` or `artistName` may be the
/// synthetic totals sentinel value `"★ TỔNG CỘNG ★"` / `"— Tất cả —"`.
/// The view layer filters these out before rendering individual rows.
public struct VenueEventRow: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let venueName: String
    public let artistName: String
    public let eventCount: Int
    public let ticketsSold: Int
    public let liveRevenue: Double
    public let avgTicketsPerEvent: Double
    public let venueRank: Int

    /// `true` when this row is a ROLLUP subtotal or grand total sentinel.
    public var isRollupRow: Bool {
        venueName.contains("★") || artistName.contains("—")
    }

    public var formattedRevenue: String {
        AppMoney.format(liveRevenue, maxFractionDigits: 0)
    }
}

// MARK: - EventRepository

/// Repository for event and venue analytics queries.
///
/// All queries delegate to `DatabaseClient.shared`. The primary query wraps
/// `sp_venue_event_analytics(p_year)` (SP7), which uses CTEs, window functions,
/// and ROLLUP to produce venue-artist-event aggregations.
public final class EventRepository: Sendable {

    private let client: DatabaseClient
    private let logger: Logger

    public init(client: DatabaseClient) {
        self.client = client
        self.logger = Logger(label: "com.labelmaster.repository.event")
    }

    // MARK: - Venue Event Analytics (SP7)

    /// Calls `sp_venue_event_analytics(p_year)` and returns all non-rollup rows.
    ///
    /// - Parameter year: The calendar year to filter events by. Defaults to current year.
    /// - Returns: An array of `VenueEventRow` ordered by venue then artist name.
    /// - Throws: `DatabaseError` on failure.
    public func fetchVenueAnalytics(year: Int) async throws -> [VenueEventRow] {
        let sql: PostgresQuery = """
            SELECT
                venue_name::text,
                nghe_si::text,
                so_su_kien::int8,
                tong_ve_ban::int8,
                doanh_thu_live::float8,
                avg_ve_per_event::float8,
                xep_hang_venue::int8
            FROM sp_venue_event_analytics(\(year)::integer)
            """

        let rows = try await client.query(sql) { row in
            let (venue, artist, events, tickets, revenue, avg, rank) =
                try row.decode(
                    (String, String, Int, Int, Double, Double, Int).self,
                    context: .default
                )
            return VenueEventRow(
                venueName: venue,
                artistName: artist,
                eventCount: events,
                ticketsSold: tickets,
                liveRevenue: revenue,
                avgTicketsPerEvent: avg,
                venueRank: rank
            )
        }
        logger.debug("EventRepository.fetchVenueAnalytics(\(year)): \(rows.count) rows")
        return rows
    }

    // MARK: - Upcoming Events

    /// Retrieves upcoming scheduled events with venue name, joined from the events table.
    ///
    /// - Returns: An array of `Event` with status `SCHEDULED` and future `event_date`,
    ///            ordered by earliest first (limit 50).
    public func fetchUpcomingEvents() async throws -> [Event] {
        let sql: PostgresQuery = """
            SELECT e.event_id,
                   e.event_name,
                   e.event_date,
                   v.venue_name,
                   e.status::text
            FROM   events e
            LEFT   JOIN venues v ON v.venue_id = e.venue_id
            WHERE  e.status = 'SCHEDULED'
              AND  e.event_date >= NOW()
            ORDER  BY e.event_date ASC
            LIMIT  50
            """

        return try await client.query(sql) { row in
            let (id, name, date, venue, statusStr) =
                try row.decode((Int, String, Date, String?, String).self, context: .default)
            guard let status = EventStatus(rawValue: statusStr) else {
                throw DatabaseError.decodingFailed("Unknown event status: '\(statusStr)'")
            }
            return Event(id: id, eventName: name, eventDate: date, venueName: venue, status: status)
        }
    }
}
