// DashboardViewModel.swift
// LabelMaster Pro
//
// Observable ViewModel that drives the RevenueRollUpView dashboard.
// Fetches rollup, pivot, and top-earner data concurrently via async let.

import Foundation
import Observation

/// The ViewModel driving the Revenue Dashboard (`RevenueRollUpView`).
///
/// Manages all state consumed by the Dashboard's KPI grid, line chart, and
/// top-earners leaderboard. Data loading is performed concurrently using
/// Swift's `async let` structured-concurrency syntax, minimising wall-clock
/// wait time when multiple queries are issued simultaneously.
///
/// ### Concurrency Model
/// All mutable published properties are mutated exclusively in `@MainActor`-isolated
/// methods so that SwiftUI re-renders happen on the main thread without `DispatchQueue`
/// bridging boilerplate.
///
/// ### Observation
/// The `@Observable` macro synthesises property observation via `_$observationRegistrar`,
/// enabling SwiftUI views to automatically track exactly which properties they access
/// rather than re-rendering on any change (as with the older `ObservableObject` protocol).
@Observable
@MainActor
final class DashboardViewModel {

    // MARK: - Published State

    /// Monthly revenue series for the `LineMark + AreaMark` chart.
    /// Each element represents one `(month, revenueType)` aggregation.
    var chartSeries: [RevenuePoint] = []

    /// Monthly pivot data for optional stacked-bar composition views.
    var pivotData: [RevenuePivotRow] = []

    /// Ranked top-earning artists for the Dashboard leaderboard table.
    var topEarners: [TopEarner] = []

    /// `true` while any network / database operation is in progress.
    var isLoading: Bool = false

    /// Non-nil when a database operation has failed; drives the `.alert` modifier.
    var errorMessage: String? = nil

    // MARK: - Computed Presentation Properties

    /// Aggregate total revenue across all categories in the loaded 12-month window.
    var totalRevenue: Double {
        chartSeries.reduce(0.0) { accumulated, point in accumulated + point.totalAmount }
    }

    /// The leading top-earner's stage name — displayed in a KPI badge.
    var topEarnerName: String {
        topEarners.first?.stageName ?? "—"
    }

    /// Total revenue formatted as a compact USD currency string (no cents).
    var formattedTotalRevenue: String {
        let formatter: NumberFormatter = NumberFormatter()
        formatter.numberStyle           = .currency
        formatter.currencyCode          = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalRevenue)) ?? "$0"
    }

    /// Gross streaming revenue across all loaded periods.
    var totalStreamingRevenue: Double {
        chartSeries
            .filter { $0.revenueType == .STREAMING }
            .reduce(0.0) { $0 + $1.totalAmount }
    }

    /// Gross sync revenue across all loaded periods.
    var totalSyncRevenue: Double {
        chartSeries
            .filter { $0.revenueType == .SYNC }
            .reduce(0.0) { $0 + $1.totalAmount }
    }

    /// Gross live revenue across all loaded periods.
    var totalLiveRevenue: Double {
        chartSeries
            .filter { $0.revenueType == .LIVE }
            .reduce(0.0) { $0 + $1.totalAmount }
    }

    // MARK: - Private Dependencies

    /// The data-access object providing revenue analytics queries.
    private let revenueRepository: RevenueRepository

    // MARK: - Initialiser

    /// Creates a `DashboardViewModel` bound to the given revenue repository.
    ///
    /// - Parameter revenueRepository: The fully initialised repository for revenue queries.
    init(revenueRepository: RevenueRepository) {
        self.revenueRepository = revenueRepository
    }

    // MARK: - Data Loading

    /// Concurrently loads the monthly rollup series, pivot data, and top-earner
    /// leaderboard, then publishes results to the observable state properties.
    ///
    /// Uses `async let` to issue all three database queries in parallel, reducing
    /// total latency to approximately the duration of the slowest individual query.
    ///
    /// Re-entrancy guard: ignores calls made while a fetch is already in progress.
    func loadAll() async {
        guard !isLoading else { return }
        isLoading    = true
        errorMessage = nil

        do {
            async let seriesTask: [RevenuePoint]    = revenueRepository.fetchMonthlyRollup(months: 12)
            async let pivotTask: [RevenuePivotRow]  = revenueRepository.fetchPivot()
            async let earnersTask: [TopEarner]      = revenueRepository.fetchTopEarners(limit: 10)

            let (series, pivot, earners) = try await (seriesTask, pivotTask, earnersTask)

            self.chartSeries = series
            self.pivotData   = pivot
            self.topEarners  = earners
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Clears all cached data and re-fetches from scratch.
    ///
    /// Useful for manual pull-to-refresh or after a fatal error dismissal.
    func refresh() async {
        chartSeries = []
        pivotData   = []
        topEarners  = []
        await loadAll()
    }
}
