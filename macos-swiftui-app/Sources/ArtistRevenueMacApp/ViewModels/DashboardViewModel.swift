// DashboardViewModel.swift
// Amplify Core
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

    /// Predicted revenue for the upcoming month using OLS regression.
    var forecastedRevenue: Double = 0.0

    /// Calculated plus/minus variance in the forecast based on historical residuals.
    var forecastedVariance: Double = 0.0

    // MARK: - Computed Presentation Properties

    /// Aggregate total revenue across all categories in the loaded 12-month window.
    var totalRevenue: Double {
        chartSeries.reduce(0.0) { accumulated, point in accumulated + point.totalAmount.nanSafe }.nonNegativeFinite
    }

    /// The leading top-earner's stage name — displayed in a KPI badge.
    var topEarnerName: String {
        topEarners.first?.stageName ?? "—"
    }

    /// Total revenue formatted as a compact USD currency string (no cents).
    var formattedTotalRevenue: String {
        AppMoney.format(totalRevenue, maxFractionDigits: 0)
    }

    /// Gross streaming revenue across all loaded periods.
    var totalStreamingRevenue: Double {
        chartSeries
            .filter { $0.revenueType == .STREAMING }
            .reduce(0.0) { $0 + $1.totalAmount.nanSafe }
            .nonNegativeFinite
    }

    /// Gross sync revenue across all loaded periods.
    var totalSyncRevenue: Double {
        chartSeries
            .filter { $0.revenueType == .SYNC }
            .reduce(0.0) { $0 + $1.totalAmount.nanSafe }
            .nonNegativeFinite
    }

    /// Gross live revenue across all loaded periods.
    var totalLiveRevenue: Double {
        chartSeries
            .filter { $0.revenueType == .LIVE }
            .reduce(0.0) { $0 + $1.totalAmount.nanSafe }
            .nonNegativeFinite
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
    func loadAll(months: Int? = 12) async {
        guard !isLoading else { return }
        isLoading    = true
        errorMessage = nil

        do {
            async let seriesTask: [RevenuePoint]    = revenueRepository.fetchMonthlyRollup(months: months)
            async let pivotTask: [RevenuePivotRow]  = revenueRepository.fetchPivot(months: months)
            async let earnersTask: [TopEarner]      = revenueRepository.fetchTopEarners(limit: 10)

            let (series, pivot, earners) = try await (seriesTask, pivotTask, earnersTask)

            self.chartSeries = series.map {
                RevenuePoint(
                    month: $0.month,
                    totalAmount: $0.totalAmount.nonNegativeFinite,
                    revenueType: $0.revenueType
                )
            }
            self.pivotData = pivot.map {
                RevenuePivotRow(
                    month: $0.month,
                    streamingAmount: $0.streamingAmount.nonNegativeFinite,
                    syncAmount: $0.syncAmount.nonNegativeFinite,
                    liveAmount: $0.liveAmount.nonNegativeFinite
                )
            }
            self.topEarners = earners.map {
                TopEarner(
                    id: $0.id,
                    stageName: $0.stageName,
                    totalRevenue: $0.totalRevenue.nonNegativeFinite
                )
            }
            
            self.calculateAIForecast()
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Extrapolates revenue for the next 30 days using an Ordinary Least Squares (OLS)
    /// linear regression mathematical baseline over the loaded historical pivot data.
    private func calculateAIForecast() {
        guard pivotData.count >= 2 else {
            forecastedRevenue = 0
            forecastedVariance = 0
            return
        }
        
        let sortedPivot = pivotData.sorted { $0.month < $1.month }
        let n = Double(sortedPivot.count)
        
        // x represents the month index (1...n), y represents total revenue
        let xValues = (1...sortedPivot.count).map { Double($0) }
        let yValues = sortedPivot.map { $0.totalAmount }
        
        let meanX = xValues.reduce(0, +) / n
        let meanY = yValues.reduce(0, +) / n
        
        var numerator = 0.0
        var denominator = 0.0
        
        for i in 0..<sortedPivot.count {
            let xDiff = xValues[i] - meanX
            let yDiff = yValues[i] - meanY
            numerator += xDiff * yDiff
            denominator += xDiff * xDiff
        }
        
        let slope = denominator != 0 ? numerator / denominator : 0
        let intercept = meanY - (slope * meanX)
        
        // Predict next month (x = n + 1)
        let rawPrediction = slope * (n + 1) + intercept
        self.forecastedRevenue = max(0, rawPrediction.nanSafe) // Floor at 0
        
        // Calculate basic variance (Root Mean Square Error bounds)
        var sumSquaredResiduals = 0.0
        for i in 0..<sortedPivot.count {
            let predictedY = slope * xValues[i] + intercept
            let residual = yValues[i] - predictedY
            sumSquaredResiduals += (residual * residual)
        }
        let rmse = sqrt((sumSquaredResiduals / n).nanSafe)
        self.forecastedVariance = rmse.nanSafe
    }

    /// Clears all cached data and re-fetches from scratch.
    ///
    /// Useful for manual pull-to-refresh or after a fatal error dismissal.
    func refresh(months: Int? = 12) async {
        chartSeries = []
        pivotData   = []
        topEarners  = []
        await loadAll(months: months)
    }
}
