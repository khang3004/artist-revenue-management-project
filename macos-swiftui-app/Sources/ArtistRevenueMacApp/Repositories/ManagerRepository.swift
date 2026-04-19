// ManagerRepository.swift
// Amplify Core
//
// Data-access layer for managers.

import Foundation
import PostgresNIO
import Logging

public final class ManagerRepository: Sendable {
    private let client: DatabaseClient
    private let logger: Logger

    public init(client: DatabaseClient) {
        self.client = client
        self.logger = Logger(label: "com.labelmaster.repository.manager")
    }

    public func fetchAll(limit: Int = 2000) async throws -> [Manager] {
        let sql: PostgresQuery = """
            SELECT manager_id,
                   manager_name,
                   phone_manager
            FROM   managers
            ORDER  BY manager_name ASC
            LIMIT  \(limit)
            """

        let items = try await client.query(sql) { row in
            let (id, name, phone) =
                try row.decode((Int, String, String?).self, context: .default)
            return Manager(id: id, name: name, phone: phone)
        }
        logger.debug("ManagerRepository.fetchAll: loaded \(items.count) managers.")
        return items
    }
}

