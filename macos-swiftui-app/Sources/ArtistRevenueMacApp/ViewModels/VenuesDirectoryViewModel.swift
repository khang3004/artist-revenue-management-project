// VenuesDirectoryViewModel.swift
// Amplify Core

import Foundation
import Observation

@Observable
@MainActor
final class VenuesDirectoryViewModel {
    var venues: [Venue] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var searchText: String = ""
    var selectedVenue: Venue? = nil

    var filteredVenues: [Venue] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return venues }
        return venues.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            ($0.address?.localizedCaseInsensitiveContains(q) ?? false) ||
            "\($0.id)".contains(q)
        }
    }

    private let repo: VenueRepository

    init(repo: VenueRepository) {
        self.repo = repo
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            venues = try await repo.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        venues = []
        await load()
    }
}

