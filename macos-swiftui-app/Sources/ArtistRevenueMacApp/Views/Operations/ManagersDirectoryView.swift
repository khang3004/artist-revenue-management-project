// ManagersDirectoryView.swift
// Amplify Core
//
// Managers directory: list + detail sheet.

import SwiftUI

struct ManagersDirectoryView: View {
    @Environment(ManagersDirectoryViewModel.self) private var vm

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
            get: { vm.selectedManager },
            set: { vm.selectedManager = $0 }
        )) { manager in
            ManagerDetailSheet(manager: manager)
        }
    }

    private var header: some View {
        @Bindable var bindable = vm
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Managers", systemImage: "person.3.fill")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Agent and management contact roster")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 12))
                    TextField("Search managers…", text: $bindable.searchText)
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
        if vm.isLoading && vm.managers.isEmpty {
            ProgressView("Loading managers…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.filteredManagers.isEmpty {
            ContentUnavailableView(
                "No Managers Found",
                systemImage: "person.3.fill",
                description: Text("Seed the database or broaden your search query.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(vm.filteredManagers) { manager in
                Button {
                    vm.selectedManager = manager
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(Brand.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.name)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Text(manager.phone ?? "—")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("#\(manager.id)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
    }
}

private struct ManagerDetailSheet: View {
    let manager: Manager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(manager.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(manager.phone ?? "—")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glass)
            }

            GlassCard(cornerRadius: 18, padding: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    detailRow(label: "Manager ID", value: "\(manager.id)")
                    detailRow(label: "Phone", value: manager.phone ?? "—")
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 340)
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

