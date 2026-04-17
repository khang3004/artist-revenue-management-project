// Album.swift
// Amplify Core
//
// Domain model for the `albums` table defined in V1__Core_Entities.sql.

import Foundation

/// Represents a music album owned by a single artist.
///
/// ### Database Mapping
/// - Primary table: `albums`
///   - `album_id`     SERIAL PRIMARY KEY
///   - `title`        VARCHAR(200) NOT NULL
///   - `release_date` DATE NOT NULL
///   - `artist_id`    INTEGER NOT NULL (FK → artists, ON DELETE CASCADE)
///
/// Conforms to `Identifiable` (keyed on `id`), `Codable`, `Hashable`, and `Sendable`.
public struct Album: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// Surrogate primary key. Corresponds to `albums.album_id`.
    public let id: Int

    /// The album's commercial title. Corresponds to `albums.title`.
    public let title: String

    /// The official release date. Corresponds to `albums.release_date` (DATE NOT NULL).
    public let releaseDate: Date

    /// Foreign key referencing the owning artist.
    /// Corresponds to `albums.artist_id` (NOT NULL, CASCADE on artist deletion).
    public let artistId: Int

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id = "albumId"
        case title, releaseDate, artistId
    }

    // MARK: - Computed Properties

    /// Returns the release year as a four-digit string (e.g., `"2024"`).
    public var releaseYear: String {
        releaseDate.formatted(.dateTime.year())
    }

    // MARK: - Memberwise Initialiser

    /// Creates an `Album` with all fields explicitly specified.
    ///
    /// - Parameters:
    ///   - id:          Surrogate primary key.
    ///   - title:       Album title.
    ///   - releaseDate: Official release date.
    ///   - artistId:    Owning artist's primary key.
    public init(id: Int, title: String, releaseDate: Date, artistId: Int) {
        self.id          = id
        self.title       = title
        self.releaseDate = releaseDate
        self.artistId    = artistId
    }
}
