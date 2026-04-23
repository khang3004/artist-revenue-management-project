// EventsViewModel.swift
// Amplify Core

import Foundation
import Observation

@Observable
@MainActor
final class EventsViewModel {

    // MARK: - State
    var venueRows: [VenueEventRow] = []
    var upcomingEvents: [Event]   = []
    var selectedYear: Int = Calendar.current.component(.year, from: Date.now)
    var isLoading: Bool   = false
    var errorMessage: String? = nil

    // MARK: - Computed
    var filteredVenueRows: [VenueEventRow] { venueRows.filter { !$0.isRollupRow } }

    var totalLiveRevenue: Double { filteredVenueRows.reduce(0) { $0 + $1.liveRevenue.nanSafe }.nonNegativeFinite }

    var totalTicketsSold: Int { filteredVenueRows.reduce(0) { $0 + $1.ticketsSold } }

    var topVenue: String {
        filteredVenueRows.min(by: { $0.venueRank < $1.venueRank })?.venueName ?? "—"
    }

    var formattedTotalRevenue: String {
        AppMoney.format(totalLiveRevenue, maxFractionDigits: 0)
    }

    // Revenue per venue for bar chart: distinct venues summed
    var revenueByVenue: [(venue: String, revenue: Double)] {
        var dict: [String: Double] = [:]
        for row in filteredVenueRows {
            dict[row.venueName, default: 0] += row.liveRevenue.nanSafe
        }
        return dict.map { (venue: $0.key, revenue: $0.value) }
            .sorted { $0.revenue > $1.revenue }
    }

    // MARK: - Dependencies
    private let repo: EventRepository

    init(repo: EventRepository) {
        self.repo = repo
    }

    // MARK: - Load
    func load() async {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        do {
            async let venueTask   = repo.fetchVenueAnalytics(year: selectedYear)
            async let upcomingTask = repo.fetchUpcomingEvents()
            let (v, u) = try await (venueTask, upcomingTask)
            venueRows = v.map {
                VenueEventRow(
                    venueName: $0.venueName,
                    artistName: $0.artistName,
                    eventCount: $0.eventCount,
                    ticketsSold: $0.ticketsSold,
                    liveRevenue: $0.liveRevenue.nonNegativeFinite,
                    avgTicketsPerEvent: $0.avgTicketsPerEvent.nanSafe,
                    venueRank: $0.venueRank
                )
            }
            upcomingEvents = u
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func changeYear(_ year: Int) async {
        selectedYear = year
        venueRows = []
        await load()
    }
}
