// AlbumCatalogView.swift
// Amplify Core
//
// Albums management: list/gallery + detail sheet.

import SwiftUI

struct AlbumCatalogView: View {
    @Environment(AlbumCatalogViewModel.self) private var vm
    @State private var layoutMode: LayoutMode = .gallery

    enum LayoutMode {
        case list
        case gallery
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .task { await vm.load() }
        .alert(
            "Load Failed",
            isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )
        ) {
            Button("Dismiss", role: .cancel) { vm.errorMessage = nil }
            Button("Retry") { Task { await vm.refresh() } }
        } message: {
            Text(vm.errorMessage ?? "An unknown error occurred.")
        }
        .sheet(item: Binding(
            get: { vm.selectedAlbum },
            set: { vm.selectedAlbum = $0 }
        )) { album in
            AlbumDetailSheet(album: album)
        }
    }

    private var header: some View {
        @Bindable var bindable = vm
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Albums Catalog", systemImage: "opticaldisc")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Full discography management")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 12))
                    TextField("Search albums…", text: $bindable.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !vm.searchText.isEmpty {
                        Button { vm.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Picker("", selection: $layoutMode) {
                    Image(systemName: "list.bullet").tag(LayoutMode.list)
                    Image(systemName: "square.grid.2x2").tag(LayoutMode.gallery)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)

                Button { Task { await vm.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.glass)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.albums.isEmpty {
            ProgressView("Loading albums…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.filteredAlbums.isEmpty {
            ContentUnavailableView(
                "No Albums Found",
                systemImage: "opticaldisc",
                description: Text("Seed the database or broaden your search query.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if layoutMode == .list {
            List(vm.filteredAlbums) { album in
                Button {
                    vm.selectedAlbum = album
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "opticaldisc")
                            .foregroundStyle(Brand.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Text("\(album.artistStageName) · \(album.releaseYear)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("#\(album.id)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    ForEach(vm.filteredAlbums) { album in
                        Button {
                            vm.selectedAlbum = album
                        } label: {
                            GlassCard(cornerRadius: 18, padding: 18) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: "opticaldisc")
                                            .foregroundStyle(Brand.secondary)
                                        Spacer()
                                        Text(album.releaseYear)
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(album.title)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .lineLimit(2)
                                    Text(album.artistStageName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text("Album #\(album.id) · Artist #\(album.artistId)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
        }
    }
}

private struct AlbumDetailSheet: View {
    let album: AlbumCatalogItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(album.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(album.artistStageName)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glass)
            }

            GlassCard(cornerRadius: 18, padding: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow(label: "Album ID", value: "\(album.id)")
                    detailRow(label: "Artist ID", value: "\(album.artistId)")
                    detailRow(label: "Release Date", value: album.releaseDate.formatted(date: .abbreviated, time: .omitted))
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 360)
        .background(.ultraThinMaterial)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Spacer()
        }
    }
}

