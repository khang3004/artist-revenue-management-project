// UniversalManagementView.swift
// Amplify Core
//
// A flexible template for management modules that haven't been fully hydrated yet.
// Provides List and Gallery layouts out-of-the-box.

import SwiftUI

struct UniversalManagementView: View {
    let title: String
    let subtitle: String
    let icon: String
    let mockPrefix: String

    @State private var layoutMode: LayoutMode = .gallery
    @State private var searchText: String = ""

    enum LayoutMode {
        case list
        case gallery
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(subtitle)
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
            List(1...10, id: \.self) { i in
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(Brand.secondary)
                    Text("\(mockPrefix) Item #\(i)").font(.headline)
                    Spacer()
                    Text("Details Unavailable").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            .listStyle(.inset)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 20) {
                    ForEach(1...12, id: \.self) { i in
                        GlassCard {
                            VStack(spacing: 12) {
                                Image(systemName: icon)
                                    .font(.system(size: 30))
                                    .foregroundStyle(Brand.secondary)
                                
                                Text("\(mockPrefix) \(i)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                
                                Text("Secondary Title")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
    }
}
