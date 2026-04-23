// ArtistDetailView.swift
// Amplify Core
//
// A comprehensive presentation sheet displaying the entire Artist domain map:
// Bio, Label, Roles, and Contract Timeline.

import SwiftUI

struct ArtistDetailView: View {
    
    let artist: Artist
    @Bindable var vm: ArtistDirectoryViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerHero
                    
                    if vm.isLoading {
                        LoadingOverlay(message: "Loading Artist Profile…")
                            .frame(height: 200)
                    } else {
                        roleAndLabelSection
                        ContractTimelineView(contracts: vm.artistContracts)
                        
                        // Placeholder sections for future deep-fetch integration
                        historicalDataSection
                    }
                }
                .padding(24)
            }
            .background(Color.clear)
            .navigationTitle(artist.stageName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .frame(minWidth: 700, minHeight: 600)
        // Fetch specific artist data when the sheet appears
        .task {
            await vm.selectArtist(artist)
        }
    }
    
    // MARK: - Subviews
    
    private var headerHero: some View {
        HStack(spacing: 20) {
            Text(String(artist.stageName.prefix(1)).uppercased())
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 100, height: 100)
                .background(
                    LinearGradient(
                        colors: [Brand.primary, Brand.secondary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: Brand.primary.opacity(0.3), radius: 15, y: 10)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(artist.stageName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                if let fName = artist.fullName {
                    Text(fName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 12) {
                    if let debut = artist.debutDate {
                        Label("Debut: \(debut.formatted(.dateTime.year()))", systemImage: "star.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Brand.amber)
                    }
                    if let dob = artist.birthday {
                        Label("DOB: \(dob.formatted(.dateTime.month().day().year()))", systemImage: "birthday.cake.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Brand.teal)
                    }
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(24)
        // Let the material background sit underneath the glass layout
        .background(Brand.primary.opacity(0.05))
        .liquidGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }
    
    private var roleAndLabelSection: some View {
        HStack(spacing: 16) {
            GlassCard(cornerRadius: 20, padding: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Creative Roles", systemImage: "person.line.dotted.person.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Brand.primary)
                    
                    if artist.roles.isEmpty {
                        Text("No assigned roles.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 8) {
                            ForEach(artist.roles) { role in
                                Text(role.displayName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Brand.emerald.gradient)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            GlassCard(cornerRadius: 20, padding: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Record Label", systemImage: "building.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Brand.primary)
                    
                    if let lId = artist.labelId, let label = vm.labels.first(where: { $0.id == lId }) {
                        Text(label.name)
                            .font(.system(size: 14, weight: .bold))
                    } else {
                        Text("Independent Artist")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var historicalDataSection: some View {
        GlassCard(cornerRadius: 20, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Discography & Event History", systemImage: "music.note.list")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Brand.primary)
                Divider()
                
                HStack(spacing: 16) {
                    summaryStat(title: "Studio Albums", value: "—", icon: "opticaldisc")
                    summaryStat(title: "Released Tracks", value: "—", icon: "music.quarternote.3")
                    summaryStat(title: "Live Events Administered", value: "—", icon: "ticket.fill")
                }
            }
        }
    }
    
    private func summaryStat(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Brand.primary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
