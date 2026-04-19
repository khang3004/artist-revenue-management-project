// AlbumRepository.swift
// Amplify Core
//
// Data-access layer for albums with joined artist name for UI presentation.

import Foundation
import PostgresNIO
import Logging

public final class AlbumRepository: Sendable {
    private let client: DatabaseClient
    private let logger: Logger

    public init(client: DatabaseClient) {
        self.client = client
        self.logger = Logger(label: "com.labelmaster.repository.album")
    }

    public func fetchAll(limit: Int = 2000) async throws -> [AlbumCatalogItem] {
        let sql: PostgresQuery = """
            SELECT al.album_id,
                   al.title,
                   al.release_date,
                   al.artist_id,
                   a.stage_name
            FROM   albums al
            JOIN   artists a ON a.artist_id = al.artist_id
            ORDER  BY al.release_date DESC, al.title ASC
            LIMIT  \(limit)
            """

        let items = try await client.query(sql) { row in
            let (id, title, releaseDate, artistId, stageName) =
                try row.decode((Int, String, Date, Int, String).self, context: .default)
            return AlbumCatalogItem(
                id: id,
                title: title,
                releaseDate: releaseDate,
                artistId: artistId,
                artistStageName: stageName
            )
        }
        logger.debug("AlbumRepository.fetchAll: loaded \(items.count) albums.")
        return items
    }
}

