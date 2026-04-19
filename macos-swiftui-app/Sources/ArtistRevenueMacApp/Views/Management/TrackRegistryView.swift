// TrackRegistryView.swift
// Amplify Core
//
// Tracks management: list/gallery + detail sheet.

import SwiftUI

struct TrackRegistryView: View {
    @Environment(TrackRegistryViewModel.self) private var vm
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
            get: { vm.selectedTrack },
            set: { vm.selectedTrack = $0 }
        )) { track in
            TrackDetailSheet(track: track)
        }
    }

    private var header: some View {
        @Bindable var bindable = vm
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Tracks Registry", systemImage: "music.note")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Individual track metadata and usage stats")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 12))
                    TextField("Search tracks…", text: $bindable.searchText)
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
        if vm.isLoading && vm.tracks.isEmpty {
            ProgressView("Loading tracks…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.filteredTracks.isEmpty {
            ContentUnavailableView(
                "No Tracks Found",
                systemImage: "music.note",
                description: Text("Seed the database or broaden your search query.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if layoutMode == .list {
            List(vm.filteredTracks) { track in
                Button {
                    vm.selectedTrack = track
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "music.note")
                            .foregroundStyle(Brand.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Text("\(track.artistStageName) · \(track.albumTitle)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(track.formattedPlayCount)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(track.formattedDuration)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(width: 90, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                    ForEach(vm.filteredTracks) { track in
                        Button {
                            vm.selectedTrack = track
                        } label: {
                            GlassCard(cornerRadius: 18, padding: 18) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Image(systemName: "music.note")
                                            .foregroundStyle(Brand.secondary)
                                        Spacer()
                                        Text(track.formattedDuration)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(track.title)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .lineLimit(2)
                                    Text(track.artistStageName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text(track.albumTitle)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    HStack {
                                        Text(track.isrc)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                        Spacer()
                                        Text(track.formattedPlayCount)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
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

private struct TrackDetailSheet: View {
    let track: TrackRegistryItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text("\(track.artistStageName) · \(track.albumTitle)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glass)
            }

            GlassCard(cornerRadius: 18, padding: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow(label: "Track ID", value: "\(track.id)")
                    detailRow(label: "ISRC", value: track.isrc)
                    detailRow(label: "Album ID", value: "\(track.albumId)")
                    detailRow(label: "Duration", value: track.formattedDuration)
                    detailRow(label: "Plays", value: track.formattedPlayCount)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 420)
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

