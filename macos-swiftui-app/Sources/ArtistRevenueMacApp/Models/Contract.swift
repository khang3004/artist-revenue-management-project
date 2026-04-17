// Contract.swift
// Amplify Core
//
// Domain model for the `contracts` ISA hierarchy defined in V3__Contracts_and_Splits.sql.
// Maps the base `contracts` table; sub-type detail tables are not individually mapped here.

import Foundation

// MARK: - ContractType

/// Discriminates the three contract ISA sub-types in the `contracts` table.
///
/// Mirrors the `contract_type` VARCHAR discriminator column:
/// `CHECK (contract_type IN ('recording', 'distribution', 'publishing'))`.
public enum ContractType: String, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    case recording
    case distribution
    case publishing

    public var id: String { rawValue }

    /// A capitalised, user-facing display label.
    public var displayName: String { rawValue.capitalized }

    /// The SF Symbol associated with this contract type for badge icons.
    public var symbolName: String {
        switch self {
        case .recording:    return "waveform.badge.mic"
        case .distribution: return "arrow.triangle.branch"
        case .publishing:   return "doc.text.fill"
        }
    }
}

// MARK: - ContractStatus

/// The lifecycle status of a contract.
///
/// Mirrors the `status` VARCHAR column constraint:
/// `CHECK (status IN ('active', 'expired', 'terminated', 'draft'))`.
public enum ContractStatus: String, Codable, Hashable, CaseIterable, Sendable {
    case active
    case expired
    case terminated
    case draft

    /// A capitalised, user-facing display label.
    public var displayName: String { rawValue.capitalized }

    /// Returns `true` only for contracts currently in the `active` state.
    public var isOperative: Bool { self == .active }
}

// MARK: - Contract

/// Represents a single contract record from the `contracts` base table.
///
/// ### Database Mapping
/// - Primary table: `contracts`
///   - `contract_id`   UUID PRIMARY KEY (gen_random_uuid())
///   - `name`          VARCHAR(200) NOT NULL
///   - `start_date`    DATE NOT NULL
///   - `end_date`      DATE (NULLABLE — `nil` = open-ended)
///   - `contract_type` VARCHAR(20) NOT NULL (discriminator)
///   - `status`        VARCHAR(20) NOT NULL DEFAULT 'active'
///   - `created_at`    TIMESTAMP NOT NULL DEFAULT NOW()
///
/// ISA sub-type details (`recording_contracts`, `distribution_contracts`,
/// `publishing_contracts`) are not hydrated here; they require a separate join.
///
/// Conforms to `Identifiable` (keyed on `id: UUID`), `Codable`, `Hashable`, and `Sendable`.
public struct Contract: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// UUID primary key. Corresponds to `contracts.contract_id`.
    public let id: UUID

    /// Human-readable contract title. Corresponds to `contracts.name`.
    public let name: String

    /// The contract's effective start date. Corresponds to `contracts.start_date`.
    public let startDate: Date

    /// The contract's expiry date. `nil` indicates an open-ended / perpetual contract.
    /// Corresponds to `contracts.end_date` (NULLABLE DATE).
    public let endDate: Date?

    /// The ISA discriminator identifying the contract sub-type.
    /// Corresponds to `contracts.contract_type`.
    public let contractType: ContractType

    /// The current lifecycle status. Corresponds to `contracts.status`.
    public let status: ContractStatus

    /// Timestamp the contract record was first inserted.
    /// Corresponds to `contracts.created_at`.
    public let createdAt: Date

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case id = "contractId"
        case name, startDate, endDate, contractType, status, createdAt
    }

    // MARK: - Computed Properties

    /// Returns `true` if status is `.active` and the current date falls within
    /// the `[startDate, endDate]` interval (open-ended contracts have no upper bound).
    public var isCurrentlyActive: Bool {
        guard status == .active else { return false }
        let now: Date = Date.now
        guard now >= startDate else { return false }
        if let end: Date = endDate { return now <= end }
        return true
    }

    /// Returns the number of calendar days remaining until contract expiry,
    /// or `nil` for open-ended contracts.
    public var daysUntilExpiry: Int? {
        guard let end: Date = endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date.now, to: end).day
    }

    // MARK: - Memberwise Initialiser

    /// Creates a `Contract` with all fields explicitly specified.
    ///
    /// - Parameters:
    ///   - id:           UUID primary key.
    ///   - name:         Human-readable contract title.
    ///   - startDate:    Effective start date.
    ///   - endDate:      Expiry date, or `nil` for open-ended contracts.
    ///   - contractType: ISA discriminator (recording / distribution / publishing).
    ///   - status:       Current lifecycle status.
    ///   - createdAt:    Row creation timestamp.
    public init(
        id: UUID,
        name: String,
        startDate: Date,
        endDate: Date?,
        contractType: ContractType,
        status: ContractStatus,
        createdAt: Date
    ) {
        self.id           = id
        self.name         = name
        self.startDate    = startDate
        self.endDate      = endDate
        self.contractType = contractType
        self.status       = status
        self.createdAt    = createdAt
    }
}
