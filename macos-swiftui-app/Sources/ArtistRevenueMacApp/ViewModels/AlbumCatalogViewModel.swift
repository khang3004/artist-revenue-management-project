// AlbumCatalogViewModel.swift
// Amplify Core

import Foundation
import Observation

@Observable
@MainActor
final class AlbumCatalogViewModel {
    var albums: [AlbumCatalogItem] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var searchText: String = ""
    var selectedAlbum: AlbumCatalogItem? = nil

    var filteredAlbums: [AlbumCatalogItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return albums }
        return albums.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.artistStageName.localizedCaseInsensitiveContains(q) ||
            "\($0.id)".contains(q)
        }
    }

    private let repo: AlbumRepository

    init(repo: AlbumRepository) {
        self.repo = repo
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            albums = try await repo.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        albums = []
        await load()
    }
}

