// ContractRepository.swift
// LabelMaster Pro
//
// Data-access layer for the `contracts` ISA hierarchy defined in V3__Contracts_and_Splits.sql.

import Foundation
import PostgresNIO
import Logging

/// Repository responsible for all data access operations on the `contracts` base table
/// and its associated ISA sub-type tables.
///
/// ### ISA Hierarchy Note
/// The `contracts` table uses a `contract_type` VARCHAR discriminator.
/// Sub-type detail tables (`recording_contracts`, `distribution_contracts`,
/// `publishing_contracts`) require additional joins to retrieve their specific fields.
/// For the initial release, only the base contract attributes are hydrated.
///
/// ### UUID Decoding
/// PostgresNIO decodes PostgreSQL `UUID` columns natively to Swift `UUID`.
/// No additional casting is required in the SQL.
///
/// Conforms to `Sendable` — immutable stored properties only.
public final class ContractRepository: Sendable {

    // MARK: - Private Properties

    private let client: DatabaseClient
    private let logger: Logger

    // MARK: - Initialiser

    /// Creates a `ContractRepository` bound to the given `DatabaseClient`.
    ///
    /// - Parameter client: The shared database connection pool actor.
    public init(client: DatabaseClient) {
        self.client = client
        self.logger = Logger(label: "com.labelmaster.repository.contract")
    }

    // MARK: - Fetch All Contracts

    /// Retrieves up to 500 contracts ordered by creation date descending.
    ///
    /// Both `contract_type` and `status` are cast to `::text` to permit
    /// `String`-based decoding, which the `ContractType` and `ContractStatus`
    /// raw-value initialisers then validate.
    ///
    /// - Returns: An array of `Contract` values ordered by descending `created_at`.
    /// - Throws:  `DatabaseError` on connection, query, or decoding failure.
    public func fetchAll() async throws -> [Contract] {
        let sql: PostgresQuery = """
            SELECT contract_id,
                   name,
                   start_date,
                   end_date,
                   contract_type::text,
                   status::text,
                   created_at
            FROM   contracts
            ORDER  BY created_at DESC
            LIMIT  500
            """

        return try await client.query(sql) { row in
            try Self.decodeContractRow(row)
        }
    }

    // MARK: - Fetch Contracts for Artist

    /// Retrieves all contracts in which a specified artist is a named beneficiary.
    ///
    /// Traverses the join chain:
    /// `contracts → contract_splits → beneficiaries → artist_beneficiaries`
    /// using `DISTINCT` to prevent row duplication when an artist holds multiple
    /// splits within the same contract.
    ///
    /// - Parameter artistId: The `artist_id` to filter beneficiaries by.
    /// - Returns: Distinct `Contract` values the artist participates in, ordered by `created_at` DESC.
    /// - Throws:  `DatabaseError` on query or decoding failure.
    public func fetchForArtist(id artistId: Int) async throws -> [Contract] {
        let sql: PostgresQuery = """
            SELECT DISTINCT
                   c.contract_id,
                   c.name,
                   c.start_date,
                   c.end_date,
                   c.contract_type::text,
                   c.status::text,
                   c.created_at
            FROM   contracts          c
            JOIN   contract_splits   cs ON cs.contract_id   = c.contract_id
            JOIN   beneficiaries      b ON  b.beneficiary_id = cs.beneficiary_id
            JOIN   artist_beneficiaries ab ON ab.beneficiary_id = b.beneficiary_id
            WHERE  ab.artist_id = \(artistId)
            ORDER  BY c.created_at DESC
            """

        let results: [Contract] = try await client.query(sql) { row in
            try Self.decodeContractRow(row)
        }
        logger.debug("ContractRepository.fetchForArtist(id:\(artistId)): \(results.count) contracts found.")
        return results
    }

    // MARK: - Private Helpers

    /// Decodes a single `PostgresRow` into a `Contract` value.
    ///
    /// Centralises the tuple-decode + enum-validation logic shared by `fetchAll`
    /// and `fetchForArtist` to avoid code duplication.
    ///
    /// - Parameter row: A raw PostgresNIO result row.
    /// - Returns: A decoded `Contract` value.
    /// - Throws:  `DatabaseError.decodingFailed` if the type or status discriminator
    ///            is not a recognised raw value.
    private static func decodeContractRow(_ row: PostgresRow) throws -> Contract {
        let (contractId, name, startDate, endDate, contractTypeStr, statusStr, createdAt) =
            try row.decode(
                (UUID, String, Date, Date?, String, String, Date).self,
                context: .default
            )

        guard let contractType: ContractType = ContractType(rawValue: contractTypeStr) else {
            throw DatabaseError.decodingFailed(
                "Unrecognised contract_type discriminator: '\(contractTypeStr)'"
            )
        }
        guard let status: ContractStatus = ContractStatus(rawValue: statusStr) else {
            throw DatabaseError.decodingFailed(
                "Unrecognised contract status: '\(statusStr)'"
            )
        }

        return Contract(
            id:           contractId,
            name:         name,
            startDate:    startDate,
            endDate:      endDate,
            contractType: contractType,
            status:       status,
            createdAt:    createdAt
        )
    }
}
