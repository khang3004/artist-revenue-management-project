// App.swift
// Amplify Core — Application Entry Point (macOS 26 Liquid Glass)
//
// Design guidelines followed:
//   • NavigationSplitView handles sidebar glass automatically — do NOT add custom backgrounds.
//   • .backgroundExtensionEffect() on the detail view lets content peek beneath the sidebar.
//   • Gradient backdrop is behind all content so glass refracts colours from it.
//   • Buttons in toolbar use .buttonStyle(.glass) or .buttonStyle(.glassProminent).

import SwiftUI

// MARK: - AppModule

enum AppModule: String, CaseIterable, Identifiable, Hashable {
    case dashboard, artists, albums, tracks, labels, analytics, events, venues, finance, managers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Revenue Dashboard"
        case .artists:   return "Artist Directory"
        case .albums:    return "Albums Catalog"
        case .tracks:    return "Tracks Registry"
        case .labels:    return "Record Labels"
        case .analytics: return "Revenue Analytics"
        case .events:    return "Live Events"
        case .venues:    return "Venues"
        case .finance:   return "Finance & Contracts"
        case .managers:  return "Managers"
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: return "waveform"
        case .artists:   return "music.mic"
        case .albums:    return "opticaldisc"
        case .tracks:    return "music.note"
        case .labels:    return "building.2.fill"
        case .analytics: return "chart.xyaxis.line"
        case .events:    return "ticket.fill"
        case .venues:    return "map.fill"
        case .finance:   return "banknote.fill"
        case .managers:  return "person.3.fill"
        }
    }

    var section: String {
        switch self {
        case .dashboard, .analytics: return "Analytics"
        case .artists, .albums, .tracks, .labels: return "Management"
        case .events, .venues, .finance, .managers: return "Operations"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {

    @Environment(DashboardViewModel.self)       private var dashboardVM
    @Environment(ArtistDirectoryViewModel.self) private var artistVM
    @Environment(EventsViewModel.self)          private var eventsVM
    @Environment(FinanceViewModel.self)         private var financeVM
    
    let artistRepo: ArtistRepository

    @State private var selectedModule: AppModule? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selectedModule)
        } detail: {
            detailContent
                // ✨ liquidGlassExtensionEffect mirrors adjacent content beneath the sidebar
                // creating a seamless, edge-to-edge glass canvas — exactly as Apple docs prescribe.
                .liquidGlassExtensionEffect()
        }
        .navigationSplitViewStyle(.balanced)
        // Prevent the sidebar from collapsing so far that the header/title wraps per-character.
        .navigationSplitViewColumnWidth(min: 260, ideal: 290, max: 360)
        // Rich gradient backdrop — glass refracts colour from whatever is behind it.
        // This creates the "floating on a coloured canvas" Liquid Glass look.
        .background(meshBackground)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        // The ScrollView's content sits on the gradient backdrop via backgroundExtensionEffect.
        Group {
            switch selectedModule {
            case .dashboard: RevenueRollUpView()
            case .artists:   ArtistDirectoryView()
            case .analytics: RevenueAnalyticsView()
            case .events:    EventsView()
            case .finance:   FinanceView()
            case .labels:    LabelDirectoryView(repo: artistRepo)
            case .albums:    AlbumCatalogView()
            case .tracks:    TrackRegistryView()
            case .venues:    VenuesDirectoryView()
            case .managers:  ManagersDirectoryView()
            case .none:
                ContentUnavailableView(
                    "Select a Module",
                    systemImage: "sidebar.left",
                    description: Text("Choose a section from the sidebar to get started.")
                )
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: selectedModule)
    }

    // MARK: - Mesh Gradient Background
    //
    // Placed BEHIND the NavigationSplitView so glass refracts these colours.
    // Apple's docs explicitly say: "Liquid Glass seeks to bring attention to
    // the underlying content." — the gradient IS the content that shines through.

    private var meshBackground: some View {
        ZStack {
            // Deep base
            Color(hue: 0.72, saturation: 0.28, brightness: 0.08)

            // Violet bloom — top leading
            RadialGradient(
                colors: [Brand.primary.opacity(0.55), .clear],
                center: .init(x: 0.15, y: 0.12),
                startRadius: 0,
                endRadius: 500
            )
            // Indigo bloom — top trailing
            RadialGradient(
                colors: [Brand.secondary.opacity(0.40), .clear],
                center: .init(x: 0.85, y: 0.08),
                startRadius: 0,
                endRadius: 420
            )
            // Teal accent — bottom leading
            RadialGradient(
                colors: [Brand.teal.opacity(0.30), .clear],
                center: .init(x: 0.08, y: 0.90),
                startRadius: 0,
                endRadius: 350
            )
            // Amber warmth — bottom trailing
            RadialGradient(
                colors: [Brand.amber.opacity(0.18), .clear],
                center: .init(x: 0.92, y: 0.88),
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - AmplifyCoreApp

@main
struct AmplifyCoreApp: App {

    @State private var dashboardVM: DashboardViewModel
    @State private var artistVM:    ArtistDirectoryViewModel
    @State private var eventsVM:    EventsViewModel
    @State private var financeVM:   FinanceViewModel
    @State private var albumsVM:    AlbumCatalogViewModel
    @State private var tracksVM:    TrackRegistryViewModel
    @State private var venuesVM:    VenuesDirectoryViewModel
    @State private var managersVM:  ManagersDirectoryViewModel
    private let artistRepo: ArtistRepository // Keep reference to pass to views if needed

    init() {
        let db = DatabaseClient.shared

        // Start DB connection pool immediately — before any view's .task modifier fires.
        Task.detached(priority: .userInitiated) {
            await db.start()
        }

        let artistRepo   = ArtistRepository(client: db)
        self.artistRepo  = artistRepo
        let revenueRepo  = RevenueRepository(client: db)
        let contractRepo = ContractRepository(client: db)
        let eventRepo    = EventRepository(client: db)
        let financeRepo  = FinanceRepository(client: db)
        let albumRepo    = AlbumRepository(client: db)
        let trackRepo    = TrackRepository(client: db)
        let venueRepo    = VenueRepository(client: db)
        let managerRepo  = ManagerRepository(client: db)

        _dashboardVM = State(initialValue: DashboardViewModel(revenueRepository: revenueRepo))
        _artistVM    = State(initialValue: ArtistDirectoryViewModel(
                                artistRepository: artistRepo,
                                contractRepository: contractRepo))
        _eventsVM    = State(initialValue: EventsViewModel(repo: eventRepo))
        _financeVM   = State(initialValue: FinanceViewModel(repo: financeRepo))
        _albumsVM    = State(initialValue: AlbumCatalogViewModel(repo: albumRepo))
        _tracksVM    = State(initialValue: TrackRegistryViewModel(repo: trackRepo))
        _venuesVM    = State(initialValue: VenuesDirectoryViewModel(repo: venueRepo))
        _managersVM  = State(initialValue: ManagersDirectoryViewModel(repo: managerRepo))
    }

    var body: some Scene {
        WindowGroup("Amplify Core") {
            ContentView(artistRepo: artistRepo)
                .environment(dashboardVM)
                .environment(artistVM)
                .environment(eventsVM)
                .environment(financeVM)
                .environment(albumsVM)
                .environment(tracksVM)
                .environment(venuesVM)
                .environment(managersVM)
                .frame(minWidth: 1100, minHeight: 720)
        }
        // ✨ .titleBar: standard macOS 26 window chrome — adopts Liquid Glass automatically
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1400, height: 860)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Amplify Core") { NSApp.orderFrontStandardAboutPanel(nil) }
            }
            CommandGroup(after: .newItem) {
                Button("Refresh Data") {
                    Task {
                        await dashboardVM.refresh()
                        await financeVM.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
