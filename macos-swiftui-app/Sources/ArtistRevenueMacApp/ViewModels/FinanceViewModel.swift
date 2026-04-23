// FinanceViewModel.swift
// Amplify Core

import Foundation
import Observation

@Observable
@MainActor
final class FinanceViewModel {

    // MARK: - State
    var contractPayouts: [ContractPayoutRow] = []
    var topTracks: [TopTrackRow]             = []
    var walletAudit: [WalletAuditRow]        = []
    var selectedYear: Int = Calendar.current.component(.year, from: Date.now)
    var selectedTopN: Int = 3
    var isLoading: Bool   = false
    var errorMessage: String? = nil

    // MARK: - Computed KPIs
    var totalPayouts: Double { contractPayouts.reduce(0) { $0 + $1.actualPayout.nanSafe }.nonNegativeFinite }
    var warningArtistCount: Int { walletAudit.filter { !$0.isHealthy }.count }
    var totalPendingWithdrawals: Double { walletAudit.reduce(0) { $0 + $1.pendingWithdrawal.nanSafe }.nonNegativeFinite }

    var formattedTotalPayouts: String {
        AppMoney.format(totalPayouts, maxFractionDigits: 0)
    }
    var formattedPendingWithdrawals: String {
        AppMoney.format(totalPendingWithdrawals, maxFractionDigits: 0)
    }

    // Payout share per beneficiary type for donut-style display
    var payoutByBeneficiaryType: [(type: String, total: Double)] {
        var dict: [String: Double] = [:]
        for row in contractPayouts { dict[row.beneficiaryType, default: 0] += row.actualPayout.nanSafe }
        return dict.map { (type: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
    }

    // Top 10 tracks by revenue for horizontal bar chart
    var topTracksForChart: [TopTrackRow] {
        Array(topTracks.sorted { $0.totalRevenue.nanSafe > $1.totalRevenue.nanSafe }.prefix(10))
    }

    // MARK: - Dependencies
    private let repo: FinanceRepository

    init(repo: FinanceRepository) {
        self.repo = repo
    }

    // MARK: - Load
    func loadAll() async {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        do {
            async let payoutsTask = repo.fetchContractPayouts()
            async let tracksTask  = repo.fetchTopTracks(topN: selectedTopN, year: selectedYear)
            async let auditTask   = repo.fetchWalletAudit()
            let (p, t, a) = try await (payoutsTask, tracksTask, auditTask)
            contractPayouts = p.map {
                ContractPayoutRow(
                    contractName: $0.contractName,
                    contractStatus: $0.contractStatus,
                    trackTitle: $0.trackTitle,
                    beneficiary: $0.beneficiary,
                    beneficiaryType: $0.beneficiaryType,
                    role: $0.role,
                    sharePct: safeShare($0.sharePct, of: 1),
                    trackTotalRevenue: $0.trackTotalRevenue.nonNegativeFinite,
                    actualPayout: $0.actualPayout.nanSafe
                )
            }
            topTracks = t.map {
                TopTrackRow(
                    artistName: $0.artistName,
                    trackTitle: $0.trackTitle,
                    albumTitle: $0.albumTitle,
                    isrc: $0.isrc,
                    playCount: $0.playCount,
                    totalRevenue: $0.totalRevenue.nonNegativeFinite,
                    rank: $0.rank
                )
            }
            walletAudit = a.map {
                WalletAuditRow(
                    artistName: $0.artistName,
                    labelName: $0.labelName,
                    genre: $0.genre,
                    walletBalance: $0.walletBalance.nanSafe,
                    totalEarned: $0.totalEarned.nanSafe,
                    totalWithdrawn: $0.totalWithdrawn.nanSafe,
                    pendingWithdrawal: $0.pendingWithdrawal.nonNegativeFinite,
                    discrepancy: $0.discrepancy.nanSafe,
                    auditStatus: $0.auditStatus
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        contractPayouts = []; topTracks = []; walletAudit = []
        await loadAll()
    }

    func reloadTracks() async {
        do {
            topTracks = try await repo.fetchTopTracks(topN: selectedTopN, year: selectedYear).map {
                TopTrackRow(
                    artistName: $0.artistName,
                    trackTitle: $0.trackTitle,
                    albumTitle: $0.albumTitle,
                    isrc: $0.isrc,
                    playCount: $0.playCount,
                    totalRevenue: $0.totalRevenue.nonNegativeFinite,
                    rank: $0.rank
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
