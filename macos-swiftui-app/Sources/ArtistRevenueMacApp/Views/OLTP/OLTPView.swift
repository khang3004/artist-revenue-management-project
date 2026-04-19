// OLTPView.swift
// Amplify Core
//
// OLTP Transactions module — ports the Streamlit `2_💰_OLTP.py` page.
// Three tabs: SP9 Register Artist, SP10 Record Revenue, SP11+SP12 Withdrawal State Machine.
//
// All stored procedure calls use DatabaseClient.callProcedure() which properly
// handles PostgreSQL 14+ CALL result rows (OUT parameters).

import SwiftUI
import PostgresNIO

// MARK: - OLTPViewModel

@Observable
@MainActor
final class OLTPViewModel {

    // MARK: - Shared state
    var isLoading: Bool = false
    var labels: [(id: Int, name: String)] = []
    var tracks: [(id: Int, title: String, artist: String)] = []
    var events: [(id: Int, name: String)] = []
    var wallets: [WalletInfo] = []

    struct WalletInfo: Identifiable {
        let id: Int           // artist_id
        let stageName: String
        let balance: Double
        let pending: Double
        var available: Double { balance - pending }
    }

    // Withdrawal state
    var withdrawals: [WithdrawalRow] = []

    struct WithdrawalRow: Identifiable {
        let id: Int
        let amount: Double
        let status: String
        let method: String
        let requested: String
    }

    // MARK: - Result feedback
    var lastResult: String? = nil
    var lastError:  String? = nil

    private let db: DatabaseClient

    init(db: DatabaseClient) { self.db = db }

    // MARK: - Load reference data

    func loadReferenceData() async {
        isLoading = true
        defer { isLoading = false }
        async let labelsTask   = fetchLabels()
        async let tracksTask   = fetchTracks()
        async let eventsTask   = fetchEvents()
        async let walletsTask  = fetchWallets()
        let (l, t, e, w) = await (labelsTask, tracksTask, eventsTask, walletsTask)
        labels  = l
        tracks  = t
        events  = e
        wallets = w
    }

    private func fetchLabels() async -> [(id: Int, name: String)] {
        let sql: PostgresQuery = "SELECT label_id, name FROM labels ORDER BY name"
        return (try? await db.query(sql) { row in
            let (id, name) = try row.decode((Int, String).self, context: .default)
            return (id: id, name: name)
        }) ?? []
    }

    private func fetchTracks() async -> [(id: Int, title: String, artist: String)] {
        let sql: PostgresQuery = """
            SELECT t.track_id, t.title, a.stage_name
            FROM tracks t
            JOIN albums al ON t.album_id = al.album_id
            JOIN artists a ON al.artist_id = a.artist_id
            ORDER BY a.stage_name, t.title LIMIT 100
            """
        return (try? await db.query(sql) { row in
            let (id, title, artist) = try row.decode((Int, String, String).self, context: .default)
            return (id: id, title: title, artist: artist)
        }) ?? []
    }

    private func fetchEvents() async -> [(id: Int, name: String)] {
        let sql: PostgresQuery = "SELECT event_id, event_name FROM events ORDER BY event_date DESC LIMIT 50"
        return (try? await db.query(sql) { row in
            let (id, name) = try row.decode((Int, String).self, context: .default)
            return (id: id, name: name)
        }) ?? []
    }

    private func fetchWallets() async -> [WalletInfo] {
        let sql: PostgresQuery = """
            SELECT a.artist_id, a.stage_name, w.balance::float8,
                   COALESCE((SELECT SUM(amount)::float8 FROM withdrawals
                             WHERE artist_id = a.artist_id AND status IN ('PENDING','APPROVED')), 0) AS pending
            FROM artists a
            JOIN artist_wallets w ON a.artist_id = w.artist_id
            ORDER BY a.stage_name
            """
        return (try? await db.query(sql) { row in
            let (id, name, balance, pending) = try row.decode((Int, String, Double, Double).self, context: .default)
            return WalletInfo(id: id, stageName: name, balance: balance, pending: pending)
        }) ?? []
    }

    func loadWithdrawals(for artistId: Int) async {
        let sql: PostgresQuery = """
            SELECT withdrawal_id, amount::float8, status, method,
                   TO_CHAR(requested_at, 'DD/MM HH24:MI')
            FROM withdrawals
            WHERE artist_id = \(artistId)
            ORDER BY requested_at DESC LIMIT 10
            """
        withdrawals = (try? await db.query(sql) { row in
            let (id, amount, status, method, requested) = try row.decode((Int, Double, String, String, String).self, context: .default)
            return WithdrawalRow(id: id, amount: amount, status: status, method: method, requested: requested)
        }) ?? []
    }

    // MARK: - SP9: Register Artist

    func registerArtist(
        stageName: String,
        fullName: String,
        labelId: Int?,
        genre: String,
        artistType: String,
        vocalRange: String?,
        penName: String?,
        memberCount: Int?
    ) async {
        isLoading = true
        lastResult = nil; lastError = nil

        let labelArg = labelId.map { "\($0)" } ?? "NULL"
        let vocalArg = vocalRange.map { "'\($0)'" } ?? "NULL"
        let penArg   = penName.flatMap { $0.isEmpty ? nil : $0 }.map { "'\($0)'" } ?? "NULL"
        let membArg  = memberCount.map { "\($0)" } ?? "NULL"
        let metaJson = "'{\"genre\": \"\(genre)\"}'::jsonb"

        let sql: PostgresQuery = """
            CALL sp_register_artist(
                '\(stageName)', '\(fullName)',
                NULL,
                \(labelArg), \(metaJson), '\(artistType)',
                \(vocalArg), \(penArg), \(membArg)
            )
            """
        do {
            let newId = try await db.callProcedure(sql) { row -> Int in
                let (id,) = try row.decode((Int,).self, context: .default)
                return id
            }
            lastResult = "✅ Artist registered! ID = \(newId.map { "\($0)" } ?? "?")"
            ToastManager.shared.show(lastResult!, style: .success)
            await loadReferenceData()
        } catch {
            lastError = error.localizedDescription
            ToastManager.shared.show("Registration failed: \(error.localizedDescription)", style: .error)
        }
        isLoading = false
    }

    // MARK: - SP10: Record Revenue

    func recordRevenue(
        trackId: Int?,
        amount: Double,
        revenueType: String,
        currency: String,
        streamCount: Int?,
        perStreamRate: Double?,
        platform: String?,
        licenseeName: String?,
        usageType: String?,
        eventId: Int?,
        ticketSold: Int?
    ) async {
        isLoading = true
        lastResult = nil; lastError = nil

        let trackArg       = trackId.map { "\($0)" }   ?? "NULL"
        let streamArg      = streamCount.map { "\($0)" } ?? "NULL"
        let rateArg        = perStreamRate.map { "\($0)" } ?? "NULL"
        let platformArg    = platform.map { "'\($0)'" }  ?? "NULL"
        let licenseeArg    = licenseeName.map { "'\($0)'" } ?? "NULL"
        let usageArg       = usageType.map { "'\($0)'" }  ?? "NULL"
        let eventArg       = eventId.map { "\($0)" }    ?? "NULL"
        let ticketArg      = ticketSold.map { "\($0)" }  ?? "NULL"

        let sql: PostgresQuery = """
            CALL sp_record_revenue(
                \(trackArg), \(amount), '\(revenueType)',
                NULL,
                '\(currency)', '{}'::jsonb,
                \(streamArg), \(rateArg), \(platformArg),
                \(licenseeArg), \(usageArg), \(eventArg), \(ticketArg)
            )
            """
        do {
            let newId = try await db.callProcedure(sql) { row -> Int in
                let (id,) = try row.decode((Int,).self, context: .default)
                return id
            }
            lastResult = "✅ Revenue logged! Log ID = \(newId.map { "\($0)" } ?? "?")"
            ToastManager.shared.show(lastResult!, style: .success)
        } catch {
            lastError = error.localizedDescription
            ToastManager.shared.show("Revenue recording failed: \(error.localizedDescription)", style: .error)
        }
        isLoading = false
    }

    // MARK: - SP11: Request Withdrawal

    func requestWithdrawal(artistId: Int, amount: Double, method: String) async {
        isLoading = true
        lastResult = nil; lastError = nil

        let sql: PostgresQuery = "CALL sp_request_withdrawal(\(artistId), \(amount), NULL, '\(method)', NULL)"
        do {
            let newId = try await db.callProcedure(sql) { row -> Int in
                let (id,) = try row.decode((Int,).self, context: .default)
                return id
            }
            lastResult = "✅ Withdrawal #\(newId.map { "\($0)" } ?? "?") created (PENDING)"
            ToastManager.shared.show(lastResult!, style: .success)
            await loadWithdrawals(for: artistId)
            await loadReferenceData()
        } catch {
            lastError = error.localizedDescription
            ToastManager.shared.show("Withdrawal failed: \(error.localizedDescription)", style: .error)
        }
        isLoading = false
    }

    // MARK: - SP12: Process Withdrawal

    func processWithdrawal(withdrawalId: Int, action: String, artistId: Int) async {
        isLoading = true
        lastResult = nil; lastError = nil

        let sql: PostgresQuery = "CALL sp_process_withdrawal(\(withdrawalId), '\(action)')"
        do {
            try await db.execute(sql)
            lastResult = "✅ Withdrawal #\(withdrawalId) → \(action)"
            ToastManager.shared.show(lastResult!, style: action == "reject" ? .warning : .success)
            await loadWithdrawals(for: artistId)
            await loadReferenceData()
        } catch {
            lastError = error.localizedDescription
            ToastManager.shared.show("Process failed: \(error.localizedDescription)", style: .error)
        }
        isLoading = false
    }
}

// MARK: - OLTPView

struct OLTPView: View {

    @State private var vm: OLTPViewModel

    init(db: DatabaseClient) {
        _vm = State(initialValue: OLTPViewModel(db: db))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                headerRow
                TabView {
                    SP9RegisterArtistTab()
                        .tabItem { Label("SP9 — Register Artist", systemImage: "person.badge.plus") }
                    SP10RecordRevenueTab()
                        .tabItem { Label("SP10 — Record Revenue", systemImage: "dollarsign.arrow.circlepath") }
                    SP11WithdrawalTab()
                        .tabItem { Label("SP11+12 — Withdrawal", systemImage: "arrow.up.right.circle.fill") }
                }
                .tabViewStyle(.automatic)
                .frame(minHeight: 550)
            }
            .padding(24)
        }
        .background(.clear)
        .environment(vm)
        .task { await vm.loadReferenceData() }
        .overlay {
            if vm.isLoading { LoadingOverlay(message: "Executing stored procedure…") }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OLTP Transactions")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("SP9 Register · SP10 Revenue · SP11/12 Withdrawal state machine")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await vm.loadReferenceData() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise.circle.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.glass).foregroundStyle(Brand.primary)
        }
    }
}

// MARK: - SP9 Register Artist Tab

private struct SP9RegisterArtistTab: View {

    @Environment(OLTPViewModel.self) private var vm

    @State private var stageName:   String = "Demo Artist"
    @State private var fullName:    String = "Nguyen Van A"
    @State private var genre:       String = "pop"
    @State private var artistType:  String = "solo"
    @State private var selectedLabel: Int? = nil
    @State private var vocalRange:  String = "C3-C6"
    @State private var penName:     String = ""
    @State private var memberCount: Int    = 4

    var body: some View {
        GlassCard(cornerRadius: 20, padding: 24) {
            VStack(alignment: .leading, spacing: 20) {

                // Procedure signature
                Label("SP9 — sp_register_artist()", systemImage: "function")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Brand.primary)

                sqlHint("""
                    CALL sp_register_artist(
                        p_stage_name, p_full_name, NULL,
                        p_label_id, p_metadata::jsonb, p_artist_type,
                        p_vocal_range, p_pen_name, p_member_count
                    )
                    """)

                Divider().overlay(Brand.border)

                // Form
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    formField("Nghệ danh *", text: $stageName)
                    formField("Tên thật", text: $fullName)
                    formField("Genre", text: $genre)

                    // Artist type picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Loại nghệ sĩ")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        Picker("", selection: $artistType) {
                            Text("Solo").tag("solo")
                            Text("Band").tag("band")
                            Text("Composer").tag("composer")
                        }
                        .pickerStyle(.segmented)
                    }

                    // Label picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Record Label")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        Picker("", selection: $selectedLabel) {
                            Text("Independent").tag(Optional<Int>.none)
                            ForEach(vm.labels, id: \.id) { label in
                                Text(label.name).tag(Optional<Int>.some(label.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Type-specific fields
                    if artistType == "solo" {
                        formField("Vocal Range", text: $vocalRange)
                    } else if artistType == "band" {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Số thành viên")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            Stepper("\(memberCount)", value: $memberCount, in: 2...20)
                                .labelsHidden()
                        }
                    } else {
                        formField("Bút danh", text: $penName)
                    }
                }

                // Result
                if let result = vm.lastResult {
                    resultBanner(result, isError: false)
                } else if let error = vm.lastError {
                    resultBanner(error, isError: true)
                }

                Button {
                    Task {
                        await vm.registerArtist(
                            stageName: stageName, fullName: fullName,
                            labelId: selectedLabel, genre: genre,
                            artistType: artistType,
                            vocalRange: artistType == "solo" ? vocalRange : nil,
                            penName:    artistType == "composer" ? penName : nil,
                            memberCount: artistType == "band" ? memberCount : nil
                        )
                    }
                } label: {
                    Label("Đăng ký nghệ sĩ", systemImage: "person.badge.plus.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .disabled(stageName.trimmingCharacters(in: .whitespaces).isEmpty)
                .controlSize(.large)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - SP10 Record Revenue Tab

private struct SP10RecordRevenueTab: View {

    @Environment(OLTPViewModel.self) private var vm

    @State private var selectedTrack:  Int?    = nil
    @State private var amount:         Double  = 50_000
    @State private var revenueType:    String  = "streaming"
    @State private var currency:       String  = "USD"
    // Streaming
    @State private var streamCount:    Int     = 1_000_000
    @State private var perStreamRate:  Double  = 0.0034
    @State private var platform:       String  = "Spotify"
    // Sync
    @State private var licenseeName:   String  = ""
    @State private var usageType:      String  = "Film"
    // Live
    @State private var selectedEvent:  Int?    = nil
    @State private var ticketSold:     Int     = 3000

    let platforms = ["Spotify", "Apple Music", "YouTube Music", "Tidal", "SoundCloud"]
    let currencies = ["USD", "EUR", "VND"]

    var body: some View {
        GlassCard(cornerRadius: 20, padding: 24) {
            VStack(alignment: .leading, spacing: 20) {

                Label("SP10 — sp_record_revenue()", systemImage: "function")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Brand.primary)

                sqlHint("CALL sp_record_revenue(p_track_id, p_amount, p_revenue_type, NULL, p_currency, '{}', ...)")

                Divider().overlay(Brand.border)

                // Revenue type selector
                GlassEffectContainer(spacing: 0) {
                    HStack(spacing: 1) {
                        ForEach([("streaming", "waveform"), ("sync", "film.fill"), ("live", "mic.fill")], id: \.0) { type, icon in
                            Button {
                                revenueType = type
                            } label: {
                                Label(type.capitalized, systemImage: icon)
                                    .font(.system(size: 12, weight: revenueType == type ? .bold : .medium))
                                    .foregroundStyle(revenueType == type ? Brand.primary : .secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(revenueType == type ? Brand.primary.opacity(0.14) : Color.clear)
                                    .liquidGlass(in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {

                    // Track picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Track")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        Picker("", selection: $selectedTrack) {
                            Text("(None / Live)").tag(Optional<Int>.none)
                            ForEach(vm.tracks, id: \.id) { t in
                                Text("\(t.artist) — \(t.title)").tag(Optional<Int>.some(t.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Amount + currency
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                        HStack {
                            TextField("Amount", value: $amount, format: .number)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                            Picker("", selection: $currency) {
                                ForEach(currencies, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 60)
                        }
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Type-specific
                    if revenueType == "streaming" {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Platform")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            Picker("", selection: $platform) {
                                ForEach(platforms, id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Streams & Rate")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            HStack {
                                TextField("Streams", value: $streamCount, format: .number)
                                    .textFieldStyle(.plain).font(.system(size: 12))
                                Text("×")
                                TextField("Rate", value: $perStreamRate, format: .number.precision(.fractionLength(4)))
                                    .textFieldStyle(.plain).font(.system(size: 12))
                            }
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    } else if revenueType == "sync" {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Licensee")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            TextField("Licensee name", text: $licenseeName)
                                .textFieldStyle(.plain).padding(8)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Usage Type")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            Picker("", selection: $usageType) {
                                ForEach(["Film", "TV", "Ad", "Game", "Other"], id: \.self) { Text($0).tag($0) }
                            }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else { // live
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Event")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            Picker("", selection: $selectedEvent) {
                                Text("(None)").tag(Optional<Int>.none)
                                ForEach(vm.events, id: \.id) { e in
                                    Text(e.name).tag(Optional<Int>.some(e.id))
                                }
                            }.pickerStyle(.menu).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tickets Sold")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            TextField("Tickets", value: $ticketSold, format: .number)
                                .textFieldStyle(.plain).padding(8)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                if let result = vm.lastResult { resultBanner(result, isError: false) }
                else if let err = vm.lastError { resultBanner(err, isError: true) }

                Button {
                    Task {
                        await vm.recordRevenue(
                            trackId: selectedTrack, amount: amount,
                            revenueType: revenueType, currency: currency,
                            streamCount: revenueType == "streaming" ? streamCount : nil,
                            perStreamRate: revenueType == "streaming" ? perStreamRate : nil,
                            platform: revenueType == "streaming" ? platform : nil,
                            licenseeName: revenueType == "sync" ? licenseeName : nil,
                            usageType: revenueType == "sync" ? usageType : nil,
                            eventId: revenueType == "live" ? selectedEvent : nil,
                            ticketSold: revenueType == "live" ? ticketSold : nil
                        )
                    }
                } label: {
                    Label("Ghi nhận doanh thu", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - SP11 + SP12 Withdrawal Tab

private struct SP11WithdrawalTab: View {

    @Environment(OLTPViewModel.self) private var vm

    @State private var selectedArtistId: Int? = nil
    @State private var withdrawalAmount: Double = 1000
    @State private var withdrawalMethod: String = "bank_transfer"
    @State private var targetWithdrawalId: Int  = 0
    @State private var processAction: String    = "approve"

    var selectedWallet: OLTPViewModel.WalletInfo? {
        guard let id = selectedArtistId else { return nil }
        return vm.wallets.first { $0.id == id }
    }

    var body: some View {
        GlassCard(cornerRadius: 20, padding: 24) {
            VStack(alignment: .leading, spacing: 20) {

                Label("SP11 + SP12 — Withdrawal State Machine", systemImage: "function")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Brand.primary)

                HStack(spacing: 8) {
                    statePill("PENDING", color: Brand.amber, arrow: true)
                    statePill("APPROVED", color: Brand.teal, arrow: true)
                    statePill("COMPLETED", color: Brand.emerald, arrow: false)
                    Text("or").font(.system(size: 11)).foregroundStyle(.secondary)
                    statePill("REJECTED", color: Brand.rose, arrow: false)
                }

                Divider().overlay(Brand.border)

                // Artist selector + wallet metrics
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nghệ sĩ")
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                    Picker("", selection: $selectedArtistId) {
                        Text("Select artist…").tag(Optional<Int>.none)
                        ForEach(vm.wallets) { w in
                            Text(w.stageName).tag(Optional<Int>.some(w.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedArtistId) { _, newId in
                        if let id = newId { Task { await vm.loadWithdrawals(for: id) } }
                    }
                }

                if let wallet = selectedWallet {
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            walletKpi("Balance", value: formatCurrency(wallet.balance), color: Brand.primary)
                            walletKpi("Pending", value: formatCurrency(wallet.pending), color: Brand.amber)
                            walletKpi("Available", value: formatCurrency(wallet.available), color: Brand.emerald)
                        }
                    }

                    Divider().overlay(Brand.border)

                    // Request withdrawal section
                    Text("SP11 — Yêu cầu rút tiền")
                        .font(.system(size: 14, weight: .semibold))

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Số tiền")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            TextField("Amount", value: $withdrawalAmount, format: .number)
                                .textFieldStyle(.plain).padding(8)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Phương thức")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                            Picker("", selection: $withdrawalMethod) {
                                Text("Bank Transfer").tag("bank_transfer")
                                Text("MoMo").tag("momo")
                                Text("ZaloPay").tag("zalopay")
                            }.pickerStyle(.menu)
                        }
                    }

                    Button {
                        Task { await vm.requestWithdrawal(artistId: wallet.id, amount: withdrawalAmount, method: withdrawalMethod) }
                    } label: {
                        Label("Yêu cầu rút", systemImage: "arrow.up.right.circle.fill")
                    }
                    .buttonStyle(.glass).foregroundStyle(Brand.primary)

                    // Withdrawal history
                    if !vm.withdrawals.isEmpty {
                        Divider().overlay(Brand.border)
                        Text("SP12 — Xử lý withdrawal")
                            .font(.system(size: 14, weight: .semibold))

                        withdrawalTable

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Withdrawal ID")
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                                TextField("ID", value: $targetWithdrawalId, format: .number)
                                    .textFieldStyle(.plain).padding(8)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                                    .frame(width: 100)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Action")
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                                Picker("", selection: $processAction) {
                                    Text("Approve").tag("approve")
                                    Text("Reject").tag("reject")
                                    Text("Complete").tag("complete")
                                }.pickerStyle(.segmented).frame(width: 220)
                            }
                        }

                        Button {
                            Task { await vm.processWithdrawal(withdrawalId: targetWithdrawalId, action: processAction, artistId: wallet.id) }
                        } label: {
                            Label("Process", systemImage: "bolt.fill")
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(targetWithdrawalId == 0)
                    }

                    if let result = vm.lastResult { resultBanner(result, isError: false) }
                    else if let err = vm.lastError { resultBanner(err, isError: true) }
                }
            }
        }
        .padding(.top, 8)
    }

    private var withdrawalTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ID").frame(width: 50, alignment: .leading)
                Text("Amount").frame(width: 100, alignment: .trailing)
                Text("Status").frame(width: 90, alignment: .center)
                Text("Method").frame(maxWidth: .infinity, alignment: .leading)
                Text("When").frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 5)

            Divider().overlay(Brand.border.opacity(0.5))

            ForEach(vm.withdrawals) { wd in
                HStack {
                    Text("#\(wd.id)").font(.system(size: 12, design: .monospaced)).frame(width: 50, alignment: .leading)
                    Text(formatCurrency(wd.amount)).font(.system(size: 12, design: .monospaced)).frame(width: 100, alignment: .trailing)
                    Text(wd.status)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(statusColor(wd.status))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(statusColor(wd.status).opacity(0.12), in: Capsule())
                        .frame(width: 90, alignment: .center)
                    Text(wd.method).font(.system(size: 11)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    Text(wd.requested).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.white.opacity(0.02))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func walletKpi(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 14))
    }

    private func statePill(_ label: String, color: Color, arrow: Bool) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(color.opacity(0.14), in: Capsule())
            if arrow {
                Image(systemName: "arrow.right").font(.system(size: 8)).foregroundStyle(.tertiary)
            }
        }
    }

    private func statusColor(_ s: String) -> Color {
        switch s.uppercased() {
        case "PENDING":   return Brand.amber
        case "APPROVED":  return Brand.teal
        case "COMPLETED": return Brand.emerald
        default:          return Brand.rose
        }
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }
}

// MARK: - Shared helpers (file-private)

private func formField(_ label: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(label)
            .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        TextField(label, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private func sqlHint(_ sql: String) -> some View {
    Text(sql)
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(10)
        .background(Brand.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .textSelection(.enabled)
}

private func resultBanner(_ message: String, isError: Bool) -> some View {
    HStack(spacing: 8) {
        Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
            .foregroundStyle(isError ? Brand.rose : Brand.emerald)
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isError ? Brand.rose : Brand.emerald)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(isError ? Brand.rose.opacity(0.08) : Brand.emerald.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
}
