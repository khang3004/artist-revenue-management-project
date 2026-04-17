// Track.swift
// Amplify Core
//
// Domain model for the `tracks` table defined in V1__Core_Entities.sql.

import Foundation

/// Represents a single audio recording belonging to a parent album.
///
/// ### Database Mapping
/// - Primary table: `tracks`
///   - `track_id`         SERIAL PRIMARY KEY
///   - `isrc`             VARCHAR(12) NOT NULL UNIQUE
///   - `title`            VARCHAR(200) NOT NULL
///   - `duration_seconds` INTEGER (NULLABLE, CHECK > 0)
///   - `album_id`         INTEGER NOT NULL (FK → albums, CASCADE)
///   - `play_count`       BIGINT NOT NULL DEFAULT 0
///
/// Conforms to `Identifiable` (keyed on `id`), `Codable`, `Hashable`, and `Sendable`.
public struct Track: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// Surrogate primary key. Corresponds to `tracks.track_id`.
    public let id: Int

    /// International Standard Recording Code — globally unique recording identifier.
    /// Corresponds to `tracks.isrc` (VARCHAR 12, UNIQUE, NOT NULL).
    public let isrc: String

    /// The track's commercial title. Corresponds to `tracks.title`.
    public let title: String

    /// Duration of the recording in seconds. `nil` if not recorded.
    /// Corresponds to `tracks.duration_seconds` (NULLABLE INTEGER, must be > 0).
    public let durationSeconds: Int?

    /// Foreign key referencing the parent album.
    /// Corresponds to `tracks.album_id` (NOT NULL, CASCADE on album deletion).
    public let albumId: Int

    /// Cumulative stream / play count. Never decreases.
    /// Corresponds to `tracks.play_count` (BIGINT, NOT NULL, DEFAULT 0).
    public let playCount: Int

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id = "trackId"
        case isrc, title, durationSeconds, albumId, playCount
    }

    // MARK: - Computed Properties

    /// Returns a human-readable duration string in `m:ss` format.
    /// Returns `"—"` if `durationSeconds` is `nil`.
    public var formattedDuration: String {
        guard let seconds: Int = durationSeconds else { return "—" }
        let minutes: Int  = seconds / 60
        let remainder: Int = seconds % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    /// Returns play count formatted with thousands separators (e.g., `"1,234,567"`).
    public var formattedPlayCount: String {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: playCount)) ?? "\(playCount)"
    }

    // MARK: - Memberwise Initialiser

    /// Creates a `Track` with all fields explicitly specified.
    ///
    /// - Parameters:
    ///   - id:              Surrogate primary key.
    ///   - isrc:            ISRC code (12-character string).
    ///   - title:           Track title.
    ///   - durationSeconds: Duration in seconds, or `nil`.
    ///   - albumId:         Parent album's primary key.
    ///   - playCount:       Cumulative stream count.
    public init(
        id: Int,
        isrc: String,
        title: String,
        durationSeconds: Int?,
        albumId: Int,
        playCount: Int
    ) {
        self.id              = id
        self.isrc            = isrc
        self.title           = title
        self.durationSeconds = durationSeconds
        self.albumId         = albumId
        self.playCount       = playCount
    }
}
