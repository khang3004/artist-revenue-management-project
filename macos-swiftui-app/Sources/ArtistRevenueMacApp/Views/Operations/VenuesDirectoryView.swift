// VenuesDirectoryView.swift
// Amplify Core
//
// Venues directory: list + detail sheet.

import SwiftUI

struct VenuesDirectoryView: View {
    @Environment(VenuesDirectoryViewModel.self) private var vm

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
            get: { vm.selectedVenue },
            set: { vm.selectedVenue = $0 }
        )) { venue in
            VenueDetailSheet(venue: venue)
        }
    }

    private var header: some View {
        @Bindable var bindable = vm
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Venues", systemImage: "map.fill")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Performance locations and capacity management")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 12))
                    TextField("Search venues…", text: $bindable.searchText)
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
        if vm.isLoading && vm.venues.isEmpty {
            ProgressView("Loading venues…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.filteredVenues.isEmpty {
            ContentUnavailableView(
                "No Venues Found",
                systemImage: "map.fill",
                description: Text("Seed the database or broaden your search query.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(vm.filteredVenues) { venue in
                Button {
                    vm.selectedVenue = venue
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "map.fill")
                            .foregroundStyle(Brand.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(venue.name)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Text(venue.address ?? "—")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(venue.capacity.map { "Cap. \($0)" } ?? "Cap. —")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
    }
}

private struct VenueDetailSheet: View {
    let venue: Venue
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(venue.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(venue.address ?? "—")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glass)
            }

            GlassCard(cornerRadius: 18, padding: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow(label: "Venue ID", value: "\(venue.id)")
                    detailRow(label: "Capacity", value: venue.capacity.map(String.init) ?? "—")
                    detailRow(label: "Address", value: venue.address ?? "—")
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 380)
        .background(.ultraThinMaterial)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

