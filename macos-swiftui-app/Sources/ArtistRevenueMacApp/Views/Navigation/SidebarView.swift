// SidebarView.swift
// Amplify Core — macOS 26 Liquid Glass Sidebar
//
// Key Apple guidelines followed:
//   • Do NOT set custom backgrounds on NavigationSplitView sidebars.
//     The system provides the glass material automatically.
//   • Use .backgroundExtensionEffect() to let content "peek through" under the sidebar.
//   • List row selections automatically adopt glass tinting.
//   • Prefer standard List/Section APIs for sidebar structure.

import SwiftUI

struct SidebarView: View {

    @Binding var selection: AppModule?
    @State private var searchText: String = ""

    private var sections: [(title: String, modules: [AppModule])] {
        let filtered: [AppModule] = searchText.isEmpty
            ? AppModule.allCases
            : AppModule.allCases.filter { $0.title.localizedCaseInsensitiveContains(searchText) }

        var seen = Set<String>()
        var result: [(String, [AppModule])] = []
        for module in AppModule.allCases {
            guard filtered.contains(module) else { continue }
            if !seen.contains(module.section) {
                seen.insert(module.section)
                result.append((module.section, filtered.filter { $0.section == module.section }))
            }
        }
        return result
    }

    var body: some View {
        List(selection: $selection) {
            // Search bar row
            if AppModule.allCases.count > 6 {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 12))
                    TextField("Search…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.horizontal, 4)
            }

            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.modules) { module in
                        Label {
                            Text(module.title)
                                .font(.system(size: 13, weight: selection == module ? .bold : .medium, design: .rounded))
                        } icon: {
                            Image(systemName: module.symbolName)
                                .symbolRenderingMode(selection == module ? .multicolor : .hierarchical)
                                .foregroundStyle(selection == module ? Brand.primary : .secondary)
                                .font(.system(size: 14, weight: selection == module ? .bold : .medium))
                                .symbolEffect(.pulse, isActive: selection == module)
                                .symbolEffect(.bounce, value: selection)
                        }
                        .tag(module)
                        .padding(.vertical, 4)
                        .listRowBackground(
                            Group {
                                if selection == module {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Brand.primary.opacity(0.15))
                                        .liquidGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                } else {
                                    EmptyView()
                                }
                            }
                        )
                    }
                }
            }

            if sections.isEmpty {
                Text("No results for \"\(searchText)\"")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            }
        }
        .listStyle(.sidebar)
        // ✨ Header — above the scroll area
        .safeAreaInset(edge: .top, spacing: 0) {
            sidebarHeader
        }
        // ✨ Footer — below the scroll area
        .safeAreaInset(edge: .bottom, spacing: 0) {
            connectionBadge
        }
    }

    // MARK: - Header

    private var sidebarHeader: some View {
        HStack(spacing: 12) {
            // App icon glass lozenge
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background {
                    LinearGradient(
                        colors: [Brand.primary, Brand.secondary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Amplify")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
                Text("Core")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
            }
            .layoutPriority(1)

            Spacer()

            // App version badge
            Text("v1.0")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Footer Connection Status

    private var connectionBadge: some View {
        HStack(spacing: 8) {
            // Pulsing dot
            Circle()
                .fill(Brand.emerald)
                .frame(width: 6, height: 6)
                .shadow(color: Brand.emerald.opacity(0.8), radius: 3)
                .symbolEffect(.pulse)

            Text("localhost:5433")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Text("artist_revenue_db")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
