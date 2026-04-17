// Event.swift
// Amplify Core
//
// Domain model for the `events` and `venues` tables defined in V4__Events_and_Venues.sql.

import Foundation

// MARK: - EventStatus

/// The operational lifecycle status of a live-performance event.
///
/// Mirrors the `event_status_enum` PostgreSQL type:
/// `ENUM ('SCHEDULED', 'COMPLETED', 'CANCELLED')`.
public enum EventStatus: String, Codable, Hashable, CaseIterable, Sendable {
    case SCHEDULED
    case COMPLETED
    case CANCELLED

    /// A title-cased, user-facing display label.
    public var displayName: String { rawValue.capitalized }

    /// The SF Symbol representing this event status in list badges.
    public var symbolName: String {
        switch self {
        case .SCHEDULED:  return "calendar.badge.clock"
        case .COMPLETED:  return "checkmark.seal.fill"
        case .CANCELLED:  return "xmark.circle.fill"
        }
    }
}

// MARK: - Event

/// Represents a live-performance event with its associated venue metadata.
///
/// ### Database Mapping
/// - Primary table: `events`
///   - `event_id`   SERIAL PRIMARY KEY
///   - `event_name` VARCHAR(200) NOT NULL
///   - `event_date` TIMESTAMP NOT NULL
///   - `venue_id`   INTEGER (NULLABLE FK → venues, ON DELETE SET NULL)
///   - `manager_id` INTEGER (NULLABLE FK → managers, ON DELETE SET NULL)
///   - `status`     event_status_enum NOT NULL DEFAULT 'SCHEDULED'
/// - Joined: `venues.venue_name` (for display purposes)
///
/// Conforms to `Identifiable` (keyed on `id`), `Codable`, `Hashable`, and `Sendable`.
public struct Event: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// Surrogate primary key. Corresponds to `events.event_id`.
    public let id: Int

    /// Descriptive name / title of the event. Corresponds to `events.event_name`.
    public let eventName: String

    /// The scheduled date and time of the event. Corresponds to `events.event_date`.
    public let eventDate: Date

    /// The hosting venue's display name, joined from `venues.venue_name`.
    /// `nil` if the venue is TBD or the venue record was deleted.
    public let venueName: String?

    /// The current lifecycle status. Corresponds to `events.status`.
    public let status: EventStatus

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id = "eventId"
        case eventName, eventDate, venueName, status
    }

    // MARK: - Computed Properties

    /// Returns a human-readable formatted date string suitable for list display
    /// (e.g., `"Apr 12, 2025 at 8:00 PM"`).
    public var formattedDate: String {
        let formatter: DateFormatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: eventDate)
    }

    /// Returns `true` if the event is scheduled and its date is in the future.
    public var isUpcoming: Bool {
        status == .SCHEDULED && eventDate > Date.now
    }

    // MARK: - Memberwise Initialiser

    /// Creates an `Event` with all fields explicitly specified.
    ///
    /// - Parameters:
    ///   - id:        Surrogate primary key.
    ///   - eventName: Descriptive event title.
    ///   - eventDate: Scheduled date and time.
    ///   - venueName: Hosting venue's display name, or `nil`.
    ///   - status:    Current lifecycle status.
    public init(
        id: Int,
        eventName: String,
        eventDate: Date,
        venueName: String?,
        status: EventStatus
    ) {
        self.id        = id
        self.eventName = eventName
        self.eventDate = eventDate
        self.venueName = venueName
        self.status    = status
    }
}
