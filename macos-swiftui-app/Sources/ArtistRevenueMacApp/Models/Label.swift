// RecordLabel.swift
// LabelMaster Pro
//
// Domain model for the `labels` table defined in V1__Core_Entities.sql.
// Named `RecordLabel` (not `Label`) to avoid shadowing SwiftUI's built-in `Label` view.

import Foundation

/// Represents a record label that signs and manages artists.
///
/// ### Naming Note
/// This type is intentionally named `RecordLabel` — not `Label` — to prevent
/// shadowing SwiftUI's `Label` view, which would cause compiler ambiguity errors
/// in every file that uses `Label { ... } icon: { ... }` syntax.
///
/// ### Database Mapping
/// - Primary table: `labels`
///   - `label_id`      SERIAL PRIMARY KEY
///   - `name`          VARCHAR(150) NOT NULL UNIQUE
///   - `founded_date`  DATE (NULLABLE)
///   - `contact_email` VARCHAR(100) (NULLABLE)
///   - `created_at`    TIMESTAMP NOT NULL DEFAULT NOW()
///
/// Conforms to `Identifiable` (keyed on `id`), `Codable`, `Hashable`, and `Sendable`.
public struct RecordLabel: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// Surrogate primary key. Corresponds to `labels.label_id`.
    public let id: Int

    /// The unique human-readable name of the label. Corresponds to `labels.name`.
    public let name: String

    /// The date on which the label was established. `nil` if not on record.
    /// Corresponds to `labels.founded_date` (NULLABLE DATE).
    public let foundedDate: Date?

    /// The primary contact e-mail address for the label. `nil` if not on record.
    /// Corresponds to `labels.contact_email` (NULLABLE VARCHAR).
    public let contactEmail: String?

    /// Timestamp the label record was first inserted.
    /// Corresponds to `labels.created_at`.
    public let createdAt: Date

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id = "labelId"
        case name, foundedDate, contactEmail, createdAt
    }

    // MARK: - Computed Properties

    /// Returns a string indicating the label's founding year, or `"Year unknown"`.
    public var foundingYear: String {
        guard let date: Date = foundedDate else { return "Year unknown" }
        return date.formatted(.dateTime.year())
    }

    // MARK: - Memberwise Initialiser

    /// Creates a `RecordLabel` with all fields explicitly specified.
    /// Intended for use by `ArtistRepository.fetchAllLabels()` row-decode closures.
    ///
    /// - Parameters:
    ///   - id:           Surrogate primary key.
    ///   - name:         Unique label name.
    ///   - foundedDate:  Label founding date, or `nil`.
    ///   - contactEmail: Primary contact e-mail, or `nil`.
    ///   - createdAt:    Row creation timestamp.
    public init(
        id: Int,
        name: String,
        foundedDate: Date?,
        contactEmail: String?,
        createdAt: Date
    ) {
        self.id           = id
        self.name         = name
        self.foundedDate  = foundedDate
        self.contactEmail = contactEmail
        self.createdAt    = createdAt
    }
}
