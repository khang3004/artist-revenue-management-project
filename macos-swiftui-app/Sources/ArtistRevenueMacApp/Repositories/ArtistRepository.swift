// ArtistRepository.swift
// Amplify Core
//
// Data-access layer for `artists`, `artist_roles`, and `labels` tables.
// Provides CRUD operations and a full-text search backed by sp8_search_artists logic.

import Foundation
import PostgresNIO
import Logging

/// Repository responsible for all data access operations on the `artists`, `artist_roles`,
/// and `labels` tables.
///
/// ### Concurrency Model
/// `ArtistRepository` is a `final class` conforming to `Sendable`. All stored state
/// (the `DatabaseClient` actor reference and the `Logger`) is immutable after initialisation,
/// making it safe to share across concurrent `Task` contexts without race conditions.
///
/// ### Role Merging Strategy
/// Because `artist_roles` is a separate junction table, `fetchAll()` issues two sequential
/// queries — one for artists and one for all roles — then merges them in Swift using a
/// dictionary keyed by `artist_id`. This avoids `GROUP BY + array_agg` complexity and
/// keeps the row decode closures to simple typed tuples.
public final class ArtistRepository: Sendable {

    // MARK: - Private Properties

    /// The shared `DatabaseClient` actor used for all query execution.
    private let client: DatabaseClient

    /// Diagnostic logger for repository-level events.
    private let logger: Logger

    // MARK: - Initialiser

    /// Creates an `ArtistRepository` bound to the given `DatabaseClient`.
    ///
    /// - Parameter client: The shared database connection pool actor.
    public init(client: DatabaseClient) {
        self.client = client
        self.logger = Logger(label: "com.labelmaster.repository.artist")
    }

    // MARK: - Fetch All Artists

    /// Retrieves all artist records ordered alphabetically by stage name, merged with
    /// their associated roles from the `artist_roles` junction table.
    ///
    /// - Returns: An array of fully-hydrated `Artist` values.
    /// - Throws:  `DatabaseError` on connection or query failure.
    public func fetchAll() async throws -> [Artist] {
        let artistSQL: PostgresQuery = """
            SELECT a.artist_id,
                   a.stage_name,
                   a.full_name,
                   a.debut_date,
                   a.birthday,
                   a.label_id,
                   a.created_at,
                   a.updated_at
            FROM   artists a
            ORDER  BY a.stage_name
            LIMIT  1000
            """

        var artists: [Artist] = try await client.query(artistSQL) { row in
            let (id, stageName, fullName, debutDate, birthday, labelId, createdAt, updatedAt) =
                try row.decode(
                    (Int, String, String?, Date?, Date?, Int?, Date, Date).self,
                    context: .default
                )
            return Artist(
                id:        id,
                stageName: stageName,
                fullName:  fullName,
                debutDate: debutDate,
                birthday:  birthday,
                labelId:   labelId,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }

        // Secondary fetch: all assigned roles (junction table).
        let roleSQL: PostgresQuery = "SELECT artist_id, role::text FROM artist_roles"
        let roleRows: [(Int, String)] = try await client.query(roleSQL) { row in
            try row.decode((Int, String).self, context: .default)
        }

        // Build a lookup dictionary and merge roles into the artist structs.
        var rolesByArtist: [Int: [ArtistRole]] = [:]
        for (artistId, roleStr) in roleRows {
            if let role: ArtistRole = ArtistRole(rawValue: roleStr) {
                rolesByArtist[artistId, default: []].append(role)
            }
        }
        for index in artists.indices {
            artists[index].roles = rolesByArtist[artists[index].id] ?? []
        }

        logger.debug("ArtistRepository.fetchAll: loaded \(artists.count) artists.")
        return artists
    }

    // MARK: - Search Artists

    /// Performs a case-insensitive partial-match search across `stage_name` and `full_name`.
    ///
    /// Replicates the logic of `sp8_search_artists` using a parameterised ILIKE predicate.
    /// The search term is safely bound as a query parameter — no SQL injection risk.
    ///
    /// - Parameter searchTerm: The free-text search string entered by the user.
    /// - Returns: Up to 100 matching `Artist` values ordered by stage name.
    /// - Throws:  `DatabaseError` on query failure.
    public func search(query searchTerm: String) async throws -> [Artist] {
        let sql: PostgresQuery = """
            SELECT a.artist_id,
                   a.stage_name,
                   a.full_name,
                   a.debut_date,
                   a.birthday,
                   a.label_id,
                   a.created_at,
                   a.updated_at
            FROM   artists a
            WHERE  a.stage_name ILIKE '%' || \(searchTerm) || '%'
               OR  COALESCE(a.full_name, '') ILIKE '%' || \(searchTerm) || '%'
            ORDER  BY a.stage_name
            LIMIT  100
            """

        return try await client.query(sql) { row in
            let (id, stageName, fullName, debutDate, birthday, labelId, createdAt, updatedAt) =
                try row.decode(
                    (Int, String, String?, Date?, Date?, Int?, Date, Date).self,
                    context: .default
                )
            return Artist(
                id:        id,
                stageName: stageName,
                fullName:  fullName,
                debutDate: debutDate,
                birthday:  birthday,
                labelId:   labelId,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    // MARK: - Create Artist

    /// Inserts a new artist record and returns the fully-created `Artist` value
    /// including the database-assigned `artist_id` and default timestamps.
    ///
    /// Uses `INSERT … RETURNING` so no secondary SELECT is required after the write.
    ///
    /// - Parameters:
    ///   - stageName: The artist's public stage name (required, non-empty).
    ///   - fullName:  The artist's legal name, or `nil`.
    ///   - labelId:   The associated label's primary key, or `nil` for independent artists.
    /// - Returns: The fully created `Artist` value with server-assigned `id` and timestamps.
    /// - Throws:  `DatabaseError` on constraint violation or query failure.
    public func create(stageName: String, fullName: String?, labelId: Int?) async throws -> Artist {
        let sql: PostgresQuery = """
            INSERT INTO artists (stage_name, full_name, label_id)
            VALUES (\(stageName), \(fullName), \(labelId))
            RETURNING artist_id, stage_name, full_name, debut_date,
                      birthday, label_id, created_at, updated_at
            """

        let results: [Artist] = try await client.query(sql) { row in
            let (id, sName, fName, debutDate, birthday, lId, createdAt, updatedAt) =
                try row.decode(
                    (Int, String, String?, Date?, Date?, Int?, Date, Date).self,
                    context: .default
                )
            return Artist(
                id:        id,
                stageName: sName,
                fullName:  fName,
                debutDate: debutDate,
                birthday:  birthday,
                labelId:   lId,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }

        guard let artist: Artist = results.first else {
            throw DatabaseError.noResults
        }
        logger.info("ArtistRepository.create: registered artist '\(artist.stageName)' (id=\(artist.id)).")
        return artist
    }

    // MARK: - Delete Artist

    /// Deletes the artist record identified by `artistId`.
    ///
    /// Because the `albums` table has `ON DELETE CASCADE`, all child albums, tracks,
    /// and related revenue log references are automatically removed by the database.
    ///
    /// - Parameter artistId: The primary key of the artist to delete.
    /// - Throws: `DatabaseError` on foreign-key constraint violations or query failure.
    public func delete(id artistId: Int) async throws {
        let sql: PostgresQuery = "DELETE FROM artists WHERE artist_id = \(artistId)"
        try await client.execute(sql)
        logger.info("ArtistRepository.delete: removed artist id=\(artistId).")
    }

    // MARK: - Fetch All Labels

    /// Retrieves all record labels ordered alphabetically — used to populate the
    /// label picker in `AddArtistSheet`.
    ///
    /// - Returns: An array of `Label` values ordered by name.
    /// - Throws:  `DatabaseError` on query failure.
    public func fetchAllLabels() async throws -> [RecordLabel] {
        let sql: PostgresQuery = """
            SELECT label_id,
                   name,
                   founded_date,
                   contact_email,
                   created_at
            FROM   labels
            ORDER  BY name
            """

        return try await client.query(sql) { row in
            let (id, name, foundedDate, contactEmail, createdAt) =
                try row.decode(
                    (Int, String, Date?, String?, Date).self,
                    context: .default
                )
            return RecordLabel(
                id:           id,
                name:         name,
                foundedDate:  foundedDate,
                contactEmail: contactEmail,
                createdAt:    createdAt
            )
        }
    }
}
