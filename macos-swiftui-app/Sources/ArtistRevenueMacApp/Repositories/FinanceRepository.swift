// FinanceRepository.swift
// Amplify Core
//
// Data-access layer for Finance module: contract revenue distribution (SP4),
// top tracks per artist (SP5), and wallet audit report (SP6).

import Foundation
import PostgresNIO
import Logging

// MARK: - ContractPayoutRow

/// One row from `sp_contract_revenue_distribution()` (SP4).
public struct ContractPayoutRow: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let contractName: String
    public let contractStatus: String
    public let trackTitle: String
    public let beneficiary: String
    public let beneficiaryType: String   // "Artist" | "Label"
    public let role: String
    public let sharePct: Double          // share_percentage (0-1)
    public let trackTotalRevenue: Double
    public let actualPayout: Double

    public var formattedPayout: String {
        AppMoney.format(actualPayout, maxFractionDigits: 0)
    }
    public var formattedShare: String { String(format: "%.1f%%", sharePct * 100) }
}

// MARK: - TopTrackRow

/// One row from `sp_top_tracks_per_artist(topN, year)` (SP5).
public struct TopTrackRow: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let artistName: String
    public let trackTitle: String
    public let albumTitle: String
    public let isrc: String
    public let playCount: Int
    public let totalRevenue: Double
    public let rank: Int

    public var formattedRevenue: String {
        AppMoney.format(totalRevenue, maxFractionDigits: 0)
    }
    public var formattedPlayCount: String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: playCount)) ?? "\(playCount)"
    }
}

// MARK: - WalletAuditRow

/// One row from `sp_wallet_audit_report()` (SP6).
public struct WalletAuditRow: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let artistName: String
    public let labelName: String?
    public let genre: String?
    public let walletBalance: Double
    public let totalEarned: Double
    public let totalWithdrawn: Double
    public let pendingWithdrawal: Double
    public let discrepancy: Double   // chenh_lech
    public let auditStatus: String   // "OK" | "CẢNH BÁO"

    public var isHealthy: Bool { auditStatus == "OK" }

    public var formattedBalance: String {
        AppMoney.format(walletBalance, maxFractionDigits: 0)
    }
    public var formattedDiscrepancy: String {
        AppMoney.format(discrepancy, maxFractionDigits: 0)
    }
}

// MARK: - FinanceRepository

/// Repository for Finance module analytic queries (SP4, SP5, SP6).
public final class FinanceRepository: Sendable {

    private let client: DatabaseClient
    private let logger: Logger

    public init(client: DatabaseClient) {
        self.client = client
        self.logger = Logger(label: "com.labelmaster.repository.finance")
    }

    // MARK: - Contract Revenue Distribution (SP4)

    /// Calls `sp_contract_revenue_distribution(p_contract_id)`.
    /// Pass `nil` to fetch all active contracts.
    public func fetchContractPayouts(contractId: UUID? = nil) async throws -> [ContractPayoutRow] {
        // Build SQL with optional UUID filter
        let sql: PostgresQuery = contractId == nil
            ? "SELECT contract_name::text, contract_status::text, track_title::text, beneficiary::text, beneficiary_type::text, role::text, share_pct::float8, track_total_revenue::float8, actual_payout::float8 FROM sp_contract_revenue_distribution()"
            : "SELECT contract_name::text, contract_status::text, track_title::text, beneficiary::text, beneficiary_type::text, role::text, share_pct::float8, track_total_revenue::float8, actual_payout::float8 FROM sp_contract_revenue_distribution(\(contractId!)::uuid)"

        return try await client.query(sql) { row in
            let (cName, cStatus, trackTitle, beneficiary, bType, role, share, trackTotal, payout) =
                try row.decode(
                    (String, String, String, String, String, String, Double, Double, Double).self,
                    context: .default
                )
            return ContractPayoutRow(
                contractName: cName, contractStatus: cStatus, trackTitle: trackTitle,
                beneficiary: beneficiary, beneficiaryType: bType, role: role,
                sharePct: share, trackTotalRevenue: trackTotal, actualPayout: payout
            )
        }
    }

    // MARK: - Top Tracks Per Artist (SP5)

    /// Calls `sp_top_tracks_per_artist(p_top_n, p_year)`.
    ///
    /// - Parameters:
    ///   - topN: Number of top tracks per artist. Defaults to 3.
    ///   - year: Calendar year filter.
    public func fetchTopTracks(topN: Int = 3, year: Int) async throws -> [TopTrackRow] {
        let sql: PostgresQuery = """
            SELECT nghe_si::text, track_title::text, album_title::text,
                   isrc::text, play_count::int8,
                   tong_doanhthu::float8, hang::int8
            FROM sp_top_tracks_per_artist(\(topN)::integer, \(year)::integer)
            """

        return try await client.query(sql) { row in
            let (artist, track, album, isrc, plays, revenue, rank) =
                try row.decode((String, String, String, String, Int, Double, Int).self, context: .default)
            return TopTrackRow(
                artistName: artist, trackTitle: track, albumTitle: album,
                isrc: isrc, playCount: plays, totalRevenue: revenue, rank: rank
            )
        }
    }

    // MARK: - Wallet Audit Report (SP6)

    /// Calls `sp_wallet_audit_report()`.
    /// Returns one row per artist comparing wallet balance vs actual contract-derived earnings.
    public func fetchWalletAudit() async throws -> [WalletAuditRow] {
        let sql: PostgresQuery = """
            SELECT nghe_si::text, label_name::text, genre::text,
                   wallet_balance::float8, total_earned::float8,
                   total_withdrawn::float8, pending_withdrawal::float8,
                   chenh_lech::float8, trang_thai::text
            FROM sp_wallet_audit_report()
            """

        return try await client.query(sql) { row in
            let (artist, label, genre, balance, earned, withdrawn, pending, diff, status) =
                try row.decode(
                    (String, String?, String?, Double, Double, Double, Double, Double, String).self,
                    context: .default
                )
            return WalletAuditRow(
                artistName: artist, labelName: label, genre: genre,
                walletBalance: balance, totalEarned: earned,
                totalWithdrawn: withdrawn, pendingWithdrawal: pending,
                discrepancy: diff, auditStatus: status
            )
        }
    }
}
