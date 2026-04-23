// LabelDirectoryView.swift
// Amplify Core
//
// Management interface for Record Labels.

import SwiftUI

@Observable
@MainActor
final class LabelDirectoryViewModel {
    var labels: [RecordLabel] = []
    var isLoading: Bool = false
    var searchText: String = ""
    
    var filteredLabels: [RecordLabel] {
        guard !searchText.isEmpty else { return labels }
        return labels.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private let repo: ArtistRepository
    
    init(repo: ArtistRepository) {
        self.repo = repo
    }
    
    func load() async {
        isLoading = true
        do {
            self.labels = try await repo.fetchAllLabels()
        } catch {
            print("Error loading labels: \(error)")
        }
        isLoading = false
    }
}

struct LabelDirectoryView: View {
    @State private var vm: LabelDirectoryViewModel
    @State private var layoutMode: LayoutMode = .gallery
    @State private var selectedLabel: RecordLabel? = nil
    
    enum LayoutMode {
        case list
        case gallery
    }

    init(repo: ArtistRepository) {
        _vm = State(initialValue: LabelDirectoryViewModel(repo: repo))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            
            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content
                    .animation(.spring(), value: layoutMode)
            }
        }
        .task { await vm.load() }
        .sheet(item: $selectedLabel) { label in
            LabelDetailSheet(label: label)
        }
    }

    private var header: some View {
        @Bindable var bindable = vm
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Record Labels")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Catalogue of affiliated and independent entities")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 12))
                    TextField("Search labels…", text: $bindable.searchText)
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
            }
        }
        .padding(24)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    @ViewBuilder
    private var content: some View {
        if layoutMode == .list {
            List(vm.filteredLabels) { label in
                Button {
                    selectedLabel = label
                } label: {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundStyle(Brand.primary)
                        Text(label.name).font(.headline)
                        Spacer()
                        if let date = label.foundedDate {
                            Text("Est. \(date.formatted(.dateTime.year()))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 8)
            }
            .listStyle(.inset)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 20) {
                    ForEach(vm.filteredLabels) { label in
                        Button {
                            selectedLabel = label
                        } label: {
                            GlassCard {
                                VStack(spacing: 12) {
                                    Image(systemName: "building.2.fill")
                                        .font(.system(size: 30))
                                        .foregroundStyle(Brand.primary)
                                    
                                    Text(label.name)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .multilineTextAlignment(.center)
                                    
                                    if let email = label.contactEmail {
                                        Text(email)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
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

private struct LabelDetailSheet: View {
    let label: RecordLabel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(label.contactEmail ?? "—")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glass)
            }

            GlassCard(cornerRadius: 18, padding: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow(label: "Label ID", value: "\(label.id)")
                    detailRow(label: "Founded", value: label.foundedDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    detailRow(label: "Created At", value: label.createdAt.formatted(date: .abbreviated, time: .shortened))
                    detailRow(label: "Email", value: label.contactEmail ?? "—")
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
