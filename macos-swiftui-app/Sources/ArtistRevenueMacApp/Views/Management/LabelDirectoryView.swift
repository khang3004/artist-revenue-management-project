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
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Record Labels")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Catalogue of affiliated and independent entities")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            
            Picker("", selection: $layoutMode) {
                Image(systemName: "list.bullet").tag(LayoutMode.list)
                Image(systemName: "square.grid.2x2").tag(LayoutMode.gallery)
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
        .padding(24)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    @ViewBuilder
    private var content: some View {
        if layoutMode == .list {
            List(vm.filteredLabels) { label in
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
                .padding(.vertical, 8)
            }
            .listStyle(.inset)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 20) {
                    ForEach(vm.filteredLabels) { label in
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
                }
                .padding(24)
            }
        }
    }
}
