// VenueRepository.swift
// Amplify Core
//
// Data-access layer for venues.

import Foundation
import PostgresNIO
import Logging

public final class VenueRepository: Sendable {
    private let client: DatabaseClient
    private let logger: Logger

    public init(client: DatabaseClient) {
        self.client = client
        self.logger = Logger(label: "com.labelmaster.repository.venue")
    }

    public func fetchAll(limit: Int = 2000) async throws -> [Venue] {
        let sql: PostgresQuery = """
            SELECT venue_id,
                   venue_name,
                   address,
                   capacity
            FROM   venues
            ORDER  BY venue_name ASC
            LIMIT  \(limit)
            """

        let items = try await client.query(sql) { row in
            let (id, name, address, capacity) =
                try row.decode((Int, String, String?, Int?).self, context: .default)
            return Venue(id: id, name: name, address: address, capacity: capacity)
        }
        logger.debug("VenueRepository.fetchAll: loaded \(items.count) venues.")
        return items
    }
}

