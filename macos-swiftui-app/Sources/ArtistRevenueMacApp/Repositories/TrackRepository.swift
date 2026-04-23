// TrackRepository.swift
// Amplify Core
//
// Data-access layer for tracks with joined album + artist names for UI presentation.

import Foundation
import PostgresNIO
import Logging

public final class TrackRepository: Sendable {
    private let client: DatabaseClient
    private let logger: Logger

    public init(client: DatabaseClient) {
        self.client = client
        self.logger = Logger(label: "com.labelmaster.repository.track")
    }

    public func fetchAll(limit: Int = 5000) async throws -> [TrackRegistryItem] {
        let sql: PostgresQuery = """
            SELECT t.track_id,
                   t.isrc,
                   t.title,
                   t.duration_seconds,
                   t.album_id,
                   t.play_count::int8,
                   al.title AS album_title,
                   a.stage_name
            FROM   tracks t
            JOIN   albums  al ON al.album_id  = t.album_id
            JOIN   artists a  ON a.artist_id  = al.artist_id
            ORDER  BY t.play_count DESC, t.title ASC
            LIMIT  \(limit)
            """

        let items = try await client.query(sql) { row in
            let (id, isrc, title, durationSeconds, albumId, playCount64, albumTitle, stageName) =
                try row.decode((Int, String, String, Int?, Int, Int64, String, String).self, context: .default)
            let playCount = Int(clamping: playCount64)
            return TrackRegistryItem(
                id: id,
                isrc: isrc,
                title: title,
                durationSeconds: durationSeconds,
                albumId: albumId,
                playCount: playCount,
                albumTitle: albumTitle,
                artistStageName: stageName
            )
        }
        logger.debug("TrackRepository.fetchAll: loaded \(items.count) tracks.")
        return items
    }
}

private extension Int {
    init(clamping value: Int64) {
        if value > Int64(Int.max) { self = Int.max; return }
        if value < Int64(Int.min) { self = Int.min; return }
        self = Int(value)
    }
}

