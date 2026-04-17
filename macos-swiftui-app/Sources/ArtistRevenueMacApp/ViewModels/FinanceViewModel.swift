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
    var totalPayouts: Double { contractPayouts.reduce(0) { $0 + $1.actualPayout } }
    var warningArtistCount: Int { walletAudit.filter { !$0.isHealthy }.count }
    var totalPendingWithdrawals: Double { walletAudit.reduce(0) { $0 + $1.pendingWithdrawal } }

    var formattedTotalPayouts: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: totalPayouts)) ?? "$0"
    }
    var formattedPendingWithdrawals: String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: totalPendingWithdrawals)) ?? "$0"
    }

    // Payout share per beneficiary type for donut-style display
    var payoutByBeneficiaryType: [(type: String, total: Double)] {
        var dict: [String: Double] = [:]
        for row in contractPayouts { dict[row.beneficiaryType, default: 0] += row.actualPayout }
        return dict.map { (type: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
    }

    // Top 10 tracks by revenue for horizontal bar chart
    var topTracksForChart: [TopTrackRow] {
        Array(topTracks.sorted { $0.totalRevenue > $1.totalRevenue }.prefix(10))
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
            contractPayouts = p
            topTracks       = t
            walletAudit     = a
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
            topTracks = try await repo.fetchTopTracks(topN: selectedTopN, year: selectedYear)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
