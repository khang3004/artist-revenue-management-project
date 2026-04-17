// ArtistWallet.swift
// LabelMaster Pro
//
// Domain model for the `artist_wallets` weak entity and its `withdrawals` table,
// defined in V5__Revenue_and_Wallets.sql.

import Foundation

/// Represents an artist's current payable balance from the `artist_wallets` weak entity.
///
/// The wallet balance accumulates from revenue split settlement events and is
/// decremented only when a corresponding `withdrawals` record transitions to
/// `COMPLETED` (enforced by the `trg_wallet_debit` trigger in `V6__Business_Rules.sql`).
///
/// ### Database Mapping
/// - Primary table: `artist_wallets`
///   - `artist_id` INTEGER PRIMARY KEY (partial key + FK → artists, CASCADE)
///   - `balance`   NUMERIC(15,2) NOT NULL DEFAULT 0 (cast to float8 in queries)
///
/// The `stage_name` field is joined from `artists` at query time for display purposes.
///
/// Conforms to `Identifiable` (keyed on `id`), `Codable`, `Hashable`, and `Sendable`.
public struct ArtistWallet: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Stored Properties

    /// The artist's primary key — serves as the wallet's partial/composite key.
    /// Corresponds to `artist_wallets.artist_id`.
    public let id: Int

    /// The artist's public stage name, joined from `artists.stage_name` for display.
    public let stageName: String

    /// The current payable balance in the base currency (USD).
    /// Must be non-negative (enforced by CHECK constraint and trigger).
    /// Decoded via `balance::float8`.
    public let balance: Double

    // MARK: - Computed Properties

    /// Returns the current balance formatted as a USD currency string with two decimal places.
    public var formattedBalance: String {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle          = .currency
        formatter.currencyCode         = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: balance)) ?? "$\(balance)"
    }

    /// Returns a relative description of the wallet health category.
    public var balanceCategory: String {
        switch balance {
        case ..<100:        return "Low Balance"
        case 100..<10_000:  return "Active"
        case 10_000...:     return "High Earner"
        default:            return "Active"
        }
    }

    // MARK: - Memberwise Initialiser

    /// Creates an `ArtistWallet` with all fields explicitly specified.
    ///
    /// - Parameters:
    ///   - id:        The artist's primary key.
    ///   - stageName: The artist's stage name (joined).
    ///   - balance:   The current payable balance as a `Double`.
    public init(id: Int, stageName: String, balance: Double) {
        self.id        = id
        self.stageName = stageName
        self.balance   = balance
    }
}
