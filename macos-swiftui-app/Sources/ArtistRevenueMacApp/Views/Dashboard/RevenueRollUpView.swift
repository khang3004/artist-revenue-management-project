// RevenueRollUpView.swift
// Amplify Core — Revenue Dashboard (macOS 26 Liquid Glass)
//
// Enhancement (2026-04):
//   • Date range picker (30d / 90d / 1y / All) passed to ViewModel
//   • Revenue mix donut chart added below KPI row
//   • Top earners card now shows a mini sparkline percentage bar per artist

import SwiftUI
import Charts

struct RevenueRollUpView: View {

    @Environment(DashboardViewModel.self) private var vm
    @State private var chartAnimated = false
    @State private var selectedPeriod: RevenuePeriod = .year

    private var safeChartSeries: [RevenuePoint] {
        vm.chartSeries.filter { $0.totalAmount.isFinite && !$0.totalAmount.isNaN }
    }

    private var donutSegments: [(label: String, value: Double, color: Color)] {
        [
            ("Streaming", vm.totalStreamingRevenue.nonNegativeFinite, Brand.teal),
            ("Sync", vm.totalSyncRevenue.nonNegativeFinite, Brand.amber),
            ("Live", vm.totalLiveRevenue.nonNegativeFinite, Brand.emerald)
        ]
    }

    private var hasDonutData: Bool {
        donutSegments.contains { $0.value > 0 }
    }

    enum RevenuePeriod: String, CaseIterable {
        case month30 = "30 Days"
        case month90 = "90 Days"
        case year    = "1 Year"
        case all     = "All Time"

        var months: Int? {
            switch self {
            case .month30: return 1
            case .month90: return 3
            case .year:    return 12
            case .all:     return nil
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                headerRow
                kpiGrid
                revenueMixDonut
                chartCard
                topEarnersCard
            }
            .padding(24)
            .scrollContentBackground(.hidden)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(.clear)
        .task { await vm.loadAll(months: selectedPeriod.months) }
        .overlay {
            if vm.isLoading { LoadingOverlay(message: "Synthesising Revenue Intelligence…") }
        }
        .alert("Data Unavailable", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("Dismiss", role: .cancel) { vm.errorMessage = nil }
            Button("Retry") { Task { await vm.refresh(months: selectedPeriod.months) } }
        } message: {
            Text(vm.errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Revenue Dashboard")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("All revenue streams · \(selectedPeriod.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            // Period picker
            GlassEffectContainer(spacing: 0) {
                HStack(spacing: 1) {
                    ForEach(RevenuePeriod.allCases, id: \.self) { period in
                        Button(period.rawValue) {
                            selectedPeriod = period
                            Task { await vm.loadAll(months: period.months) }
                        }
                        .font(.system(size: 11, weight: selectedPeriod == period ? .bold : .medium))
                        .foregroundStyle(selectedPeriod == period ? Brand.primary : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedPeriod == period ? Brand.primary.opacity(0.14) : Color.clear)
                        .liquidGlass(in: Capsule())
                    }
                }
            }

            Button {
                Task { await vm.refresh(months: selectedPeriod.months) }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - KPI Grid

    private var kpiGrid: some View {
        GlassEffectContainer(spacing: 12) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                spacing: 12
            ) {
                StatBadge(icon: "dollarsign.circle.fill",
                          label: "Total Revenue",
                          value: vm.formattedTotalRevenue, trend: .up, accentColor: Brand.primary)
                StatBadge(icon: "music.note",
                          label: "Streaming",
                          value: formatAmt(vm.totalStreamingRevenue), trend: .up, accentColor: Brand.teal)
                StatBadge(icon: "film.fill",
                          label: "Sync & Licensing",
                          value: formatAmt(vm.totalSyncRevenue), trend: .neutral, accentColor: Brand.amber)
                StatBadge(icon: "mic.fill",
                          label: "Live Performance",
                          value: formatAmt(vm.totalLiveRevenue), trend: .up, accentColor: Brand.emerald)
                StatBadge(icon: "sparkles",
                          label: "AI Forecast (30d)",
                          value: formatAmt(vm.forecastedRevenue), trend: .neutral, accentColor: .purple)
            }
        }
    }

    // MARK: - Revenue Mix Donut

    private var revenueMixDonut: some View {
        GlassCard(cornerRadius: 20, padding: 24) {
            HStack(spacing: 32) {
                // Donut
                VStack(spacing: 8) {
                    if hasDonutData {
                        Chart {
                            ForEach(donutSegments, id: \.label) { segment in
                                SectorMark(
                                    angle: .value(segment.label, segment.value),
                                    innerRadius: .ratio(0.62),
                                    angularInset: 2
                                )
                                .foregroundStyle(segment.color)
                                .cornerRadius(4)
                            }
                        }
                        .frame(width: 120, height: 120)
                        .overlay {
                            VStack(spacing: 2) {
                                Text("Mix")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(vm.formattedTotalRevenue)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    } else {
                        Circle()
                            .stroke(Brand.border, lineWidth: 2)
                            .frame(width: 100, height: 100)
                    }
                }

                // Legend with share bars
                VStack(alignment: .leading, spacing: 14) {
                    Text("Revenue Mix")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))

                    donutLegendRow(label: "Streaming",       color: Brand.teal,    amount: vm.totalStreamingRevenue.nonNegativeFinite, total: vm.totalRevenue.nonNegativeFinite)
                    donutLegendRow(label: "Sync & Licensing", color: Brand.amber,   amount: vm.totalSyncRevenue.nonNegativeFinite,       total: vm.totalRevenue.nonNegativeFinite)
                    donutLegendRow(label: "Live Performance", color: Brand.emerald, amount: vm.totalLiveRevenue.nonNegativeFinite,       total: vm.totalRevenue.nonNegativeFinite)
                }

                Spacer()
            }
        }
    }

    private func donutLegendRow(label: String, color: Color, amount: Double, total: Double) -> some View {
        let share = safeShare(amount, of: total)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(String(format: "%.1f%%", share * 100))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                Text(formatAmt(amount))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 72, alignment: .trailing)
            }
            // Canvas progress bar — NaN-safe
            Canvas { ctx, size in
                let width = size.width.nanSafe
                let height = size.height.nanSafe
                let track = Path(CGRect(x: 0, y: 0, width: width, height: height))
                ctx.fill(track, with: .color(Brand.border))
                let fillW = width * min(max(share, 0), 1)
                if fillW > 0 {
                    let fill = Path(CGRect(x: 0, y: 0, width: fillW.nanSafe, height: height))
                    ctx.fill(fill, with: .color(color))
                }
            }
            .clipShape(Capsule())
            .frame(height: 3)
        }
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        GlassCard(cornerRadius: 20, padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Revenue Trends")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("Monthly breakdown by category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    legendStack
                }

                if safeChartSeries.isEmpty && !vm.isLoading {
                    ContentUnavailableView(
                        "No Revenue Data",
                        systemImage: "chart.line.downtrend.xyaxis",
                        description: Text("Connect to the database and seed revenue logs.")
                    )
                    .frame(height: 260)
                } else {
                    revenueLineChart
                }
            }
        }
    }

    private var legendStack: some View {
        GlassEffectContainer(spacing: 0) {
            HStack(spacing: 1) {
                ForEach([("Streaming", Brand.teal),
                         ("Sync", Brand.amber),
                         ("Live", Brand.emerald)], id: \.0) { item in
                    HStack(spacing: 5) {
                        Circle().fill(item.1).frame(width: 7, height: 7)
                        Text(item.0)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlass(in: Capsule())
                }
            }
        }
    }

    private var revenueLineChart: some View {
        Chart(safeChartSeries) { point in
            let animatedAmount = chartAnimated ? point.totalAmount.nonNegativeFinite : 0
            LineMark(
                x: .value("Month",   point.month,       unit: .month),
                y: .value("Revenue", animatedAmount),
                series: .value("Category", point.revenueType.rawValue)
            )
            .foregroundStyle(by: .value("Category", point.revenueType.rawValue))
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .symbol(Circle().strokeBorder(lineWidth: 1.5))
            .symbolSize(30)

            AreaMark(
                x: .value("Month",   point.month,       unit: .month),
                y: .value("Revenue", animatedAmount),
                series: .value("Category", point.revenueType.rawValue)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [colorFor(point.revenueType).opacity(0.22), .clear],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
        .chartForegroundStyleScale([
            RevenueType.STREAMING.rawValue: Brand.teal,
            RevenueType.SYNC.rawValue:      Brand.amber,
            RevenueType.LIVE.rawValue:      Brand.emerald
        ])
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(.separator)
                AxisValueLabel(format: .dateTime.month(.abbreviated), centered: false)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(.separator)
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(abbrev(d.nanSafe)).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 270)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.76).delay(0.1)) {
                chartAnimated = true
            }
        }
        .onChange(of: safeChartSeries) { _, _ in
            chartAnimated = false
            withAnimation(.spring(response: 0.9, dampingFraction: 0.76).delay(0.1)) {
                chartAnimated = true
            }
        }
    }

    // MARK: - Top Earners

    private var topEarnersCard: some View {
        GlassCard(cornerRadius: 20, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Top Earning Artists", systemImage: "trophy.fill")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(Brand.primary)
                    Spacer()
                    Text("Ranked by cumulative gross revenue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if vm.topEarners.isEmpty && !vm.isLoading {
                    Text("No revenue data available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
                    let maxRevenue = vm.topEarners.first.map { $0.totalRevenue.nonNegativeFinite } ?? 1
                    ForEach(Array(vm.topEarners.enumerated()), id: \.offset) { idx, earner in
                        earnerRow(rank: idx + 1, earner: earner, maxRevenue: maxRevenue)
                        if idx < vm.topEarners.count - 1 {
                            Divider().padding(.leading, 50).opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    private func earnerRow(rank: Int, earner: TopEarner, maxRevenue: Double) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Rank
                Group {
                    if rank <= 3 {
                        Text("#\(rank)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Brand.primary)
                            .frame(width: 28, height: 28)
                            .background(Brand.primary.opacity(0.15))
                            .liquidGlass(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Text("#\(rank)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                    }
                }

                // Avatar
                Text(String(earner.stageName.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Brand.primary)
                    .frame(width: 34, height: 34)
                    .background(Brand.primary.opacity(0.15))
                    .liquidGlass(in: Circle())

                Text(earner.stageName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Text(earner.formattedRevenue)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }

            // Mini share bar
            let share = safeShare(earner.totalRevenue.nonNegativeFinite, of: maxRevenue.nonNegativeFinite)
            Canvas { ctx, size in
                let width = size.width.nanSafe
                let height = size.height.nanSafe
                let bg = Path(CGRect(x: 0, y: 0, width: width, height: height))
                ctx.fill(bg, with: .color(Brand.border.opacity(0.5)))
                let fw = width * share
                if fw > 0 {
                    let fill = Path(CGRect(x: 0, y: 0, width: fw.nanSafe, height: height))
                    ctx.fill(fill, with: .color(Brand.primary.opacity(0.5)))
                }
            }
            .clipShape(Capsule())
            .frame(height: 2)
            .padding(.leading, 74)
        }
        .padding(.vertical, 5)
    }

    // MARK: - Helpers

    private func colorFor(_ type: RevenueType) -> Color {
        switch type {
        case .STREAMING: Brand.teal
        case .SYNC:      Brand.amber
        case .LIVE:      Brand.emerald
        }
    }

    private func formatAmt(_ v: Double) -> String {
        AppMoney.format(v, maxFractionDigits: 0)
    }

    private func abbrev(_ v: Double) -> String {
        AppMoney.formatCompact(v)
    }
}
