// RevenueRollUpView.swift
// Amplify Core — Revenue Dashboard (macOS 26 Liquid Glass)

import SwiftUI
import Charts

struct RevenueRollUpView: View {

    @Environment(DashboardViewModel.self) private var vm
    @State private var chartAnimated = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                headerRow
                kpiGrid
                chartCard
                topEarnersCard
            }
            .padding(24)
            // scrollEdgeEffectStyle: system blurs content scrolling beneath toolbar
            .scrollContentBackground(.hidden)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(.clear)
        .task { await vm.loadAll() }
        .overlay {
            if vm.isLoading { LoadingOverlay(message: "Synthesising Revenue Intelligence…") }
        }
        .alert("Data Unavailable", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("Dismiss", role: .cancel) { vm.errorMessage = nil }
            Button("Retry") { Task { await vm.refresh() } }
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
                Text("Trailing 12-month aggregate · all revenue streams")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // ✨ Glass button — native Liquid Glass style, no custom backgrounds
            Button {
                Task { await vm.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - KPI Grid
    //
    // Wrapped in GlassEffectContainer so the four cards can morphically merge/separate.

    private var kpiGrid: some View {
        GlassEffectContainer(spacing: 12) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                spacing: 12
            ) {
                StatBadge(icon: "dollarsign.circle.fill",
                          label: "Total Revenue (12 mo)",
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

    // MARK: - Chart Card

    private var chartCard: some View {
        GlassCard(cornerRadius: 20, padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
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

                if vm.chartSeries.isEmpty && !vm.isLoading {
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
        // ✨ GlassEffectContainer so the three legend chips can morph together
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
        Chart(vm.chartSeries) { point in
            LineMark(
                x: .value("Month",   point.month,       unit: .month),
                y: .value("Revenue", chartAnimated ? point.totalAmount : 0)
            )
            .foregroundStyle(colorFor(point.revenueType))
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .symbol(Circle().strokeBorder(lineWidth: 1.5))
            .symbolSize(30)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Month",   point.month,       unit: .month),
                y: .value("Revenue", chartAnimated ? point.totalAmount : 0)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [colorFor(point.revenueType).opacity(0.22), .clear],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartForegroundStyleScale([
            "Streaming": Brand.teal,
            "Sync":      Brand.amber,
            "Live":      Brand.emerald
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
                        Text(abbrev(d)).font(.system(size: 10)).foregroundStyle(.secondary)
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
        .onChange(of: vm.chartSeries) { _, _ in
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
                    ForEach(Array(vm.topEarners.enumerated()), id: \.offset) { idx, earner in
                        earnerRow(rank: idx + 1, earner: earner)
                        if idx < vm.topEarners.count - 1 {
                            Divider().padding(.leading, 50).opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    private func earnerRow(rank: Int, earner: TopEarner) -> some View {
        HStack(spacing: 12) {
            // Rank — glass lozenge for top 3
            Group {
                if rank <= 3 {
                    Text("#\(rank)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Brand.primary)
                        .frame(width: 28, height: 28)
                        .background(Brand.primary.opacity(0.15))
                        .liquidGlass(
                                     in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                .liquidGlass(
                             in: Circle())

            Text(earner.stageName)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer()

            Text(earner.formattedRevenue)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
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
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }

    private func abbrev(_ v: Double) -> String {
        switch v {
        case 1_000_000...: String(format: "$%.1fM", v / 1_000_000)
        case 1_000...:     String(format: "$%.0fK", v / 1_000)
        default:           String(format: "$%.0f", v)
        }
    }
}
