// ManagersDirectoryViewModel.swift
// Amplify Core

import Foundation
import Observation

@Observable
@MainActor
final class ManagersDirectoryViewModel {
    var managers: [Manager] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var searchText: String = ""
    var selectedManager: Manager? = nil

    var filteredManagers: [Manager] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return managers }
        return managers.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            ($0.phone?.localizedCaseInsensitiveContains(q) ?? false) ||
            "\($0.id)".contains(q)
        }
    }

    private let repo: ManagerRepository

    init(repo: ManagerRepository) {
        self.repo = repo
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            managers = try await repo.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        managers = []
        await load()
    }
}

