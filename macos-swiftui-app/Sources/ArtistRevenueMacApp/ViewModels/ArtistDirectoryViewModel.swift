// ArtistDirectoryViewModel.swift
// Amplify Core
//
// Observable ViewModel driving the ArtistDirectoryView CRUD interface.

import Foundation
import Observation

/// The ViewModel driving the Artist Directory (`ArtistDirectoryView`).
///
/// Manages the full artist list, label catalogue, selected-artist contracts,
/// search text, and all mutation operations (create, delete). Uses `@Observable`
/// for fine-grained property tracking rather than full-view invalidation.
///
/// ### Client-side Filtering
/// `filteredArtists` is a computed property that filters the in-memory `artists`
/// array using `localizedCaseInsensitiveContains`. This avoids a network round-trip
/// for every keystroke and ensures instant feedback while the user types. A separate
/// server-side search via `ArtistRepository.search(query:)` can be triggered for
/// broader results.
///
/// ### Delete Flow
/// Deletion follows a confirm-then-execute pattern:
/// 1. `confirmDelete(artist:)` stores `artistToDelete` and raises `showDeleteConfirmation`.
/// 2. The view presents a `confirmationDialog`.
/// 3. On confirmation, `deleteArtist()` calls the repository and removes from the array.
@Observable
@MainActor
final class ArtistDirectoryViewModel {

    // MARK: - Published State

    /// The full artist roster, loaded on view appearance.
    var artists: [Artist] = []

    /// All record labels — used to populate the label picker in `AddArtistSheet`.
    var labels: [RecordLabel] = []

    /// Contracts associated with the currently selected artist.
    var artistContracts: [Contract] = []

    /// The artist currently selected in the list, driving the detail panel.
    var selectedArtist: Artist? = nil

    /// The free-text string entered in the search field.
    var searchText: String = ""

    /// `true` while an asynchronous data operation is in progress.
    var isLoading: Bool = false

    /// Non-nil when an operation has failed; drives the error `.alert`.
    var errorMessage: String? = nil

    /// `true` when the Add Artist modal sheet should be presented.
    var showAddArtistSheet: Bool = false

    /// `true` when the delete confirmation dialog should be presented.
    var showDeleteConfirmation: Bool = false

    /// The artist staged for deletion — populated by `confirmDelete(artist:)`.
    var artistToDelete: Artist? = nil

    // MARK: - Computed Properties

    /// Returns artists filtered by `searchText` using a case-insensitive partial match
    /// on both `stageName` and `fullName`. If `searchText` is empty, returns all artists.
    var filteredArtists: [Artist] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return artists }
        return artists.filter { artist in
            artist.stageName.localizedCaseInsensitiveContains(searchText)
            || (artist.fullName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Private Dependencies

    private let artistRepository: ArtistRepository
    private let contractRepository: ContractRepository

    // MARK: - Initialiser

    /// Creates an `ArtistDirectoryViewModel` bound to the given repositories.
    ///
    /// - Parameters:
    ///   - artistRepository:   Repository for artist CRUD and label listing.
    ///   - contractRepository: Repository for contract retrieval by artist.
    init(artistRepository: ArtistRepository, contractRepository: ContractRepository) {
        self.artistRepository   = artistRepository
        self.contractRepository = contractRepository
    }

    // MARK: - Data Loading

    /// Concurrently loads all artists and all labels.
    ///
    /// Both queries are issued in parallel via `async let` to minimise latency.
    /// Existing cached data is not cleared until new results arrive, preventing
    /// a flash of empty content on refresh.
    func loadArtists() async {
        guard !isLoading else { return }
        isLoading    = true
        errorMessage = nil

        do {
            async let artistsTask: [Artist] = artistRepository.fetchAll()
            async let labelsTask: [RecordLabel] = artistRepository.fetchAllLabels()

            let (fetchedArtists, fetchedLabels) = try await (artistsTask, labelsTask)
            self.artists = fetchedArtists
            self.labels  = fetchedLabels
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Selection

    /// Selects an artist and asynchronously loads its associated contracts
    /// into `artistContracts` for display in the detail panel.
    ///
    /// - Parameter artist: The artist the user tapped in the list.
    func selectArtist(_ artist: Artist) async {
        selectedArtist  = artist
        artistContracts = []

        do {
            self.artistContracts = try await contractRepository.fetchForArtist(id: artist.id)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create

    /// Inserts a new artist via the repository and appends the result to the local array.
    ///
    /// Empty `fullName` strings are coerced to `nil` before submission to avoid
    /// storing empty-string values in a nullable column.
    ///
    /// - Parameters:
    ///   - stageName: The artist's public stage name (required).
    ///   - fullName:  Optional legal name; `nil` or empty strings are stored as NULL.
    ///   - labelId:   Optional label FK. `nil` for independent artists.
    func createArtist(stageName: String, fullName: String?, labelId: Int?) async {
        let sanitisedFullName: String? = fullName.flatMap {
            $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0
        }

        do {
            let created: Artist = try await artistRepository.create(
                stageName: stageName.trimmingCharacters(in: .whitespaces),
                fullName:  sanitisedFullName,
                labelId:   labelId
            )
            self.artists.append(created)
            self.artists.sort { $0.stageName < $1.stageName }
            await selectArtist(created)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    /// Stages `artist` for deletion and raises the confirmation dialog.
    ///
    /// The actual deletion is deferred until `deleteArtist()` is called from the
    /// confirmation dialog's destructive action handler.
    ///
    /// - Parameter artist: The artist the user has chosen to delete.
    func confirmDelete(artist: Artist) {
        artistToDelete      = artist
        showDeleteConfirmation = true
    }

    /// Executes the staged deletion after the user confirms the dialog.
    ///
    /// On success, removes the artist from the local array and clears the detail
    /// panel if the deleted artist was previously selected.
    ///
    /// Silently returns if no artist has been staged via `confirmDelete(artist:)`.
    func deleteArtist() async {
        guard let artist: Artist = artistToDelete else { return }

        do {
            try await artistRepository.delete(id: artist.id)
            self.artists.removeAll { $0.id == artist.id }

            if selectedArtist?.id == artist.id {
                selectedArtist  = nil
                artistContracts = []
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        artistToDelete = nil
    }
}
