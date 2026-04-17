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

    private var sections: [(title: String, modules: [AppModule])] {
        var seen = Set<String>()
        var result: [(String, [AppModule])] = []
        for module in AppModule.allCases {
            if !seen.contains(module.section) {
                seen.insert(module.section)
                result.append((module.section, AppModule.allCases.filter { $0.section == module.section }))
            }
        }
        return result
    }

    var body: some View {
        List(selection: $selection) {
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
                    // Gradient behind glass so it picks up color
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
                Text("Core")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Brand.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 14)
        // No custom background — sidebar material handles it
    }

    // MARK: - Footer Connection Status

    private var connectionBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Brand.emerald)
                .frame(width: 6, height: 6)
                .shadow(color: Brand.emerald, radius: 3)

            Text("localhost:5433")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Small glass chip for the status badge
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
