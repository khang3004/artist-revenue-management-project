// TrackRegistryViewModel.swift
// Amplify Core

import Foundation
import Observation

@Observable
@MainActor
final class TrackRegistryViewModel {
    var tracks: [TrackRegistryItem] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var searchText: String = ""
    var selectedTrack: TrackRegistryItem? = nil

    var filteredTracks: [TrackRegistryItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return tracks }
        return tracks.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.isrc.localizedCaseInsensitiveContains(q) ||
            $0.albumTitle.localizedCaseInsensitiveContains(q) ||
            $0.artistStageName.localizedCaseInsensitiveContains(q) ||
            "\($0.id)".contains(q)
        }
    }

    private let repo: TrackRepository

    init(repo: TrackRepository) {
        self.repo = repo
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            tracks = try await repo.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        tracks = []
        await load()
    }
}

