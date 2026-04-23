// ArtistDirectoryView.swift
// Amplify Core
//
// Full CRUD management interface for artists: searchable list panel + detail panel
// with biography, role badges, contract log, and Add/Delete operations.

import SwiftUI

// MARK: - ArtistDirectoryView

/// The Artist Directory module — a two-panel CRUD interface for managing artists,
/// their label affiliations, and associated contracts.
///
/// ### Layout
/// Uses a fixed-width left panel (`ArtistListPanel`) and a fluid right panel
/// (`ArtistDetailPanel`) joined by a `Divider`. This avoids a nested
/// `NavigationSplitView` which would conflict with the app's root split view.
///
/// ### Error Handling
/// Database errors are surfaced as a system `Alert`. Delete operations trigger
/// a `confirmationDialog` before irreversible execution.
///
/// ### CRUD Operations
/// - **Read**: `viewModel.loadArtists()` on `.task`.
/// - **Create**: `AddArtistSheet` modal sheet via toolbar `+` button.
/// - **Delete**: Context menu → confirm dialog → `viewModel.deleteArtist()`.
/// - **Select**: Tap a row → `viewModel.selectArtist(_:)` hydrates the detail panel.
struct ArtistDirectoryView: View {

    @Environment(ArtistDirectoryViewModel.self) private var viewModel
    @State private var artistForDetail: Artist? = nil
    @State private var layoutMode: LayoutMode = .list

    enum LayoutMode {
        case list
        case gallery
    }

    var body: some View {
        VStack(spacing: 0) {
            // View Switcher Header
            HStack {
                Text("Catalogue Layout")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                Picker("", selection: $layoutMode) {
                    Label("List", systemImage: "list.bullet").tag(LayoutMode.list)
                    Label("Gallery", systemImage: "square.grid.2x2").tag(LayoutMode.gallery)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial.opacity(0.5))

            HStack(spacing: 0) {
                if layoutMode == .list {
                    ArtistListPanel()
                        .frame(width: 300)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    
                    Divider()
                    
                    ArtistDetailPanel(artistForDetail: $artistForDetail)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ArtistGalleryGrid(artistForDetail: $artistForDetail)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: layoutMode)
        }
        .environment(viewModel)
        .task { await viewModel.loadArtists() }
        // Error alert
        .alert(
            "Operation Failed",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("Dismiss", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "An undocumented error occurred.")
        }
        // Delete confirmation dialog
        .confirmationDialog(
            "Delete Artist",
            isPresented: Binding(
                get: { viewModel.showDeleteConfirmation },
                set: { viewModel.showDeleteConfirmation = $0 }
            ),
            presenting: viewModel.artistToDelete
        ) { artist in
            Button("Delete \"\(artist.stageName)\"", role: .destructive) {
                Task { await viewModel.deleteArtist() }
            }
            Button("Cancel", role: .cancel) {
                viewModel.artistToDelete = nil
            }
        } message: { artist in
            Text(
                "This will permanently remove \"\(artist.stageName)\" and all child "
                + "albums, tracks, and revenue attributions. This action cannot be undone."
            )
        }
        // Add artist modal sheet
        .sheet(isPresented: Binding(
            get: { viewModel.showAddArtistSheet },
            set: { viewModel.showAddArtistSheet = $0 }
        )) {
            AddArtistSheet()
                .environment(viewModel)
        }
        // Deep profile modal sheet
        .sheet(item: $artistForDetail) { artist in
            ArtistDetailView(artist: artist, vm: viewModel)
        }
    }
}

// MARK: - Artist List Panel

/// The left panel of `ArtistDirectoryView`: a searchable list of artist roster entries.
private struct ArtistListPanel: View {

    @Environment(ArtistDirectoryViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            searchBar
            Divider()
            artistList
        }
    }

    // Panel header with title + add button
    private var panelHeader: some View {
        HStack {
            Text("Artists")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            Spacer()

            Button {
                viewModel.showAddArtistSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Brand.primary)
                    .symbolEffect(.bounce.down.byLayer, value: viewModel.showAddArtistSheet)
            }
            .buttonStyle(.plain)
        }
    }

    // Search bar with clear button
    private var searchBar: some View {
        @Bindable var vm = viewModel
        return HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 13))

            TextField("Search artists…", text: $vm.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
    }

    // Main artist list
    @ViewBuilder
    private var artistList: some View {
        if viewModel.isLoading && viewModel.artists.isEmpty {
            Spacer()
            ProgressView("Retrieving Artist Roster…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        } else if viewModel.filteredArtists.isEmpty {
            Spacer()
            ContentUnavailableView(
                "No Artists Found",
                systemImage: "mic.circle",
                description: Text("Register artists using the + button or broaden your search query.")
            )
            Spacer()
        } else {
            List(
                viewModel.filteredArtists,
                selection: Binding<Artist?>(
                    get: { viewModel.selectedArtist },
                    set: { if let artist = $0 { Task { await viewModel.selectArtist(artist) } } }
                )
            ) { artist in
                ArtistRowCell(artist: artist)
                    .tag(artist)
                    .contextMenu {
                        Button(role: .destructive) {
                            viewModel.confirmDelete(artist: artist)
                        } label: {
                            Label("Delete Artist", systemImage: "trash")
                        }
                    }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Artist Row Cell

/// A compact list-row widget displaying an artist's avatar initial, stage name, and role pills.
private struct ArtistRowCell: View {

    let artist: Artist

    var body: some View {
        HStack(spacing: 10) {
            // Avatar initial circle
            ZStack {
                Circle()
                    .fill(Brand.primary.opacity(0.16))
                    .frame(width: 36, height: 36)
                Text(String(artist.stageName.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(artist.stageName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                // Role pills
                HStack(spacing: 3) {
                    ForEach(artist.roles.prefix(2)) { role in
                        Text(role.displayName)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Brand.primary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background { Capsule().fill(Brand.primary.opacity(0.12)) }
                    }
                    if artist.roles.isEmpty {
                        Text("Unclassified")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Artist Detail Panel

/// The fluid right panel, rendering the selected artist's profile card,
/// biographical grid, and associated contracts list.
private struct ArtistDetailPanel: View {

    @Binding var artistForDetail: Artist?
    @Environment(ArtistDirectoryViewModel.self) private var viewModel

    var body: some View {
        if let artist: Artist = viewModel.selectedArtist {
            ArtistProfileView(artist: artist, contracts: viewModel.artistContracts, artistForDetail: $artistForDetail)
        } else {
            ContentUnavailableView(
                "No Artist Selected",
                systemImage: "person.crop.circle.dashed",
                description: Text("Select an artist from the directory to view their full profile and contract history.")
            )
        }
    }
}

// MARK: - Artist Profile View

/// The scrollable profile content for a selected artist, including header card,
/// biographical detail grid, and contract log.
private struct ArtistProfileView: View {

    let artist: Artist
    let contracts: [Contract]
    @Binding var artistForDetail: Artist?

    @State private var appeared: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeaderCard
                biographyCard
                if !contracts.isEmpty { contractsCard }
            }
            .padding(24)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                appeared = true
            }
        }
        .onChange(of: artist.id) { _, _ in
            appeared = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.04)) {
                appeared = true
            }
        }
    }

    // Hero profile card
    private var profileHeaderCard: some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            HStack(spacing: 20) {
                // Gradient avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Brand.primary, Brand.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    Text(String(artist.stageName.prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(artist.stageName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    if let fullName: String = artist.fullName {
                        Text(fullName)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }

                    // Role chips
                    HStack(spacing: 6) {
                        ForEach(artist.roles) { role in
                            Label(role.displayName, systemImage: role.symbolName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Brand.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background { Capsule().fill(Brand.primary.opacity(0.12)) }
                        }
                    }
                }

                Spacer()

                // Right-aligned metadata stats
                VStack(alignment: .trailing, spacing: 8) {
                    if let age: Int = artist.age {
                        metaStat(label: "Age", value: "\(age)")
                    }
                    if let debut: Date = artist.debutDate {
                        metaStat(
                            label: "Debut",
                            value: debut.formatted(.dateTime.year().month(.abbreviated))
                        )
                    }
                    metaStat(label: "Artist ID", value: "#\(artist.id)")
                    
                    Spacer()
                    
                    Button("Deep Profile") {
                        artistForDetail = artist
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
        }
    }

    // Biographical detail grid card
    private var biographyCard: some View {
        GlassCard(cornerRadius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Profile Details", systemImage: "person.text.rectangle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Brand.primary)

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    detailRow(label: "Stage Name", value: artist.stageName)

                    if let fullName: String = artist.fullName {
                        detailRow(label: "Legal Name", value: fullName)
                    }
                    if let birthday: Date = artist.birthday {
                        detailRow(
                            label: "Date of Birth",
                            value: birthday.formatted(.dateTime.day().month().year())
                        )
                    }
                    if let debutDate: Date = artist.debutDate {
                        detailRow(
                            label: "Debut Date",
                            value: debutDate.formatted(.dateTime.day().month().year())
                        )
                    }
                    detailRow(
                        label: "Label Affiliation",
                        value: artist.labelId.map { "Label #\($0)" } ?? "Independent Artist"
                    )
                    detailRow(
                        label: "Record Created",
                        value: artist.createdAt.formatted(.dateTime.day().month().year())
                    )
                }
            }
        }
    }

    // Contract history card
    private var contractsCard: some View {
        GlassCard(cornerRadius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Contracts", systemImage: "doc.text.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Brand.primary)
                    Spacer()
                    Text("\(contracts.count) agreement\(contracts.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Divider()

                ForEach(contracts) { contract in
                    ContractRowView(contract: contract)
                    if contract.id != contracts.last?.id {
                        Divider().padding(.leading, 40).overlay(Brand.border.opacity(0.5))
                    }
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func metaStat(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .gridCellAnchor(.trailing)

            Text(value)
                .font(.system(size: 12))
                .gridCellAnchor(.leading)
        }
    }
}

// MARK: - Contract Row View

/// A compact row displaying a contract's type icon, name, effective dates, and status badge.
private struct ContractRowView: View {

    let contract: Contract

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: contract.contractType.symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Brand.primary)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Brand.primary.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(contract.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(
                    "\(contract.contractType.displayName) · "
                    + contract.startDate.formatted(.dateTime.day().month(.abbreviated).year())
                )
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Status badge pill
            Text(contract.status.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(contract.status == .active ? Brand.emerald : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background {
                    Capsule()
                        .fill(
                            contract.status == .active
                            ? Brand.emerald.opacity(0.12)
                            : Color.secondary.opacity(0.10)
                        )
                }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Artist Sheet

/// A modal form enabling creation of a new artist record.
///
/// Submits validated user input through `ArtistDirectoryViewModel.createArtist(...)`.
/// The form is dismissed automatically on successful creation.
private struct AddArtistSheet: View {

    @Environment(ArtistDirectoryViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var stageName: String = ""
    @State private var fullName: String = ""
    @State private var selectedLabelId: Int? = nil

    /// `true` when the required `stageName` field contains non-whitespace text.
    private var isFormValid: Bool {
        !stageName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Artist Identity") {
                    TextField("Stage Name *", text: $stageName)
                    TextField("Full Legal Name", text: $fullName)
                }

                Section("Label Affiliation") {
                    Picker("Record Label", selection: $selectedLabelId) {
                        Text("Independent (Unaffiliated)").tag(Optional<Int>.none)
                        ForEach(viewModel.labels) { label in
                            Text(label.name).tag(Optional<Int>.some(label.id))
                        }
                    }
                }

                Section {
                    Text(
                        "Fields marked with * are required. "
                        + "Additional attributes (debut date, birthday, roles, metadata) "
                        + "can be configured after the initial registration."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Register New Artist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Register") {
                        Task {
                            await viewModel.createArtist(
                                stageName: stageName,
                                fullName:  fullName.isEmpty ? nil : fullName,
                                labelId:   selectedLabelId
                            )
                            dismiss()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .frame(width: 480, height: 370)
    }
}
// MARK: - Artist Gallery Grid

/// A visual grid of artists displayed as "Profile Cards" with glass effects.
private struct ArtistGalleryGrid: View {
    @Environment(ArtistDirectoryViewModel.self) private var viewModel
    @Binding var artistForDetail: Artist?

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(viewModel.filteredArtists) { artist in
                    ArtistGalleryCard(artist: artist)
                        .onTapGesture {
                            artistForDetail = artist
                        }
                }
            }
            .padding(24)
        }
        .background(Brand.primary.opacity(0.02))
    }
}

private struct ArtistGalleryCard: View {
    let artist: Artist

    var body: some View {
        GlassCard(cornerRadius: 24, padding: 0) {
            VStack(spacing: 16) {
                // Large Avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Brand.primary, Brand.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                    Text(String(artist.stageName.prefix(1)).uppercased())
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 24)

                VStack(spacing: 4) {
                    Text(artist.stageName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    
                    if let role = artist.roles.first?.displayName {
                        Text(role)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Brand.primary)
                    Text("View Detail")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.bottom, 20)
            }
        }
    }
}
