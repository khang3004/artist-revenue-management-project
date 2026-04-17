// Artist.swift
// LabelMaster Pro
//
// Domain model for the `artists` base table and its `artist_roles` junction table.
// Maps the ISA parent entity from V1__Core_Entities.sql and V2__ISA_Artists.sql.

import Foundation

// MARK: - ArtistRole

/// The set of roles an artist can simultaneously hold within the system.
///
/// Mirrors the `artist_role_enum` PostgreSQL type defined in `V1__Core_Entities.sql`.
/// Artists may hold multiple roles concurrently (e.g., `solo` and `composer`).
public enum ArtistRole: String, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    case solo
    case band
    case composer
    case producer

    public var id: String { rawValue }

    /// A capitalised, human-readable label suitable for display in badges and lists.
    public var displayName: String {
        switch self {
        case .solo:     return "Solo Artist"
        case .band:     return "Band"
        case .composer: return "Composer"
        case .producer: return "Producer"
        }
    }

    /// The SF Symbol associated with this role — used for icon rendering in `ArtistRowCell`.
    public var symbolName: String {
        switch self {
        case .solo:     return "person.fill"
        case .band:     return "mic.circle.fill"
        case .composer: return "music.note.list"
        case .producer: return "slider.horizontal.3"
        }
    }
}

// MARK: - Artist

/// Represents a single artist entity from the `artists` base table,
/// augmented with ISA role membership from the `artist_roles` junction table.
///
/// ### Database Mapping
/// - Primary table: `artists` (columns: `artist_id`, `stage_name`, `full_name`,
///   `debut_date`, `birthday`, `label_id`, `created_at`, `updated_at`)
/// - Associated: `artist_roles` joined via `artist_id`
///
/// ### ISA Hierarchy
/// Sub-type tables (`bands`, `composers`, `producers`) are not mapped here for
/// brevity; their discriminating data is exposed only through the `roles` array.
///
/// Conforms to `Identifiable` (keyed on `id`), `Codable` for local serialisation,
/// `Hashable` for SwiftUI `List` selection sets, and `Sendable` for actor-safe transfer.
public struct Artist: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// Surrogate primary key. Corresponds to `artists.artist_id` (SERIAL → INT4).
    public let id: Int

    /// The artist's public stage name. Corresponds to `artists.stage_name` (NOT NULL).
    public let stageName: String

    /// The artist's legal full name. `nil` if not on record.
    /// Corresponds to `artists.full_name` (NULLABLE VARCHAR).
    public let fullName: String?

    /// The artist's official public debut date. `nil` if not recorded.
    /// Corresponds to `artists.debut_date` (NULLABLE DATE).
    public let debutDate: Date?

    /// The artist's date of birth. `nil` if not recorded.
    /// Corresponds to `artists.birthday` (NULLABLE DATE).
    public let birthday: Date?

    /// Foreign key referencing the associated record label.
    /// `nil` indicates an unaffiliated (independent) artist.
    /// Corresponds to `artists.label_id` (NULLABLE INT4, ON DELETE SET NULL).
    public let labelId: Int?

    /// Timestamp the artist record was first inserted.
    /// Corresponds to `artists.created_at` (TIMESTAMP NOT NULL DEFAULT NOW()).
    public let createdAt: Date

    /// Timestamp of the most recent modification, managed by the `trg_artists_updated_at` trigger.
    /// Corresponds to `artists.updated_at`.
    public let updatedAt: Date

    /// The set of roles assigned to this artist via the `artist_roles` junction table.
    /// Populated by `ArtistRepository` after a secondary role-fetch and merge.
    /// May be empty if no roles have been assigned.
    public var roles: [ArtistRole]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id = "artistId"
        case stageName, fullName, debutDate, birthday
        case labelId, createdAt, updatedAt, roles
    }

    // MARK: - Computed Properties

    /// Returns the artist's approximate age in whole years, or `nil` if birthday is unavailable.
    public var age: Int? {
        guard let birthday: Date = birthday else { return nil }
        let components: DateComponents = Calendar.current.dateComponents(
            [.year], from: birthday, to: Date.now
        )
        return components.year
    }

    /// Returns a single-line display string combining the stage name with the primary role.
    /// Falls back to `stageName` alone if no roles have been assigned.
    public var displayTitle: String {
        guard let primaryRole: ArtistRole = roles.first else { return stageName }
        return "\(stageName) · \(primaryRole.displayName)"
    }

    // MARK: - Memberwise Initialiser

    /// Creates an `Artist` with all fields explicitly specified.
    /// Intended for use by `ArtistRepository` row-decode closures.
    ///
    /// - Parameters:
    ///   - id:          Surrogate primary key.
    ///   - stageName:   Public stage name (required).
    ///   - fullName:    Legal full name, or `nil`.
    ///   - debutDate:   Official debut date, or `nil`.
    ///   - birthday:    Date of birth, or `nil`.
    ///   - labelId:     Associated label FK, or `nil`.
    ///   - createdAt:   Row creation timestamp.
    ///   - updatedAt:   Row last-modification timestamp.
    ///   - roles:       Assigned roles (defaults to empty; merged post-fetch).
    public init(
        id: Int,
        stageName: String,
        fullName: String?,
        debutDate: Date?,
        birthday: Date?,
        labelId: Int?,
        createdAt: Date,
        updatedAt: Date,
        roles: [ArtistRole] = []
    ) {
        self.id        = id
        self.stageName = stageName
        self.fullName  = fullName
        self.debutDate = debutDate
        self.birthday  = birthday
        self.labelId   = labelId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.roles     = roles
    }
}
