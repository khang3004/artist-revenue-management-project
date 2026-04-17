// RevenueAnalyticsView.swift
// Amplify Core
//
// Revenue Analytics module: artist×month rollup table (SP1),
// source pivot stacked bar (SP2), and top tracks table — mirrors Streamlit page 3.

import SwiftUI
import Charts

struct RevenueAnalyticsView: View {

    @Environment(DashboardViewModel.self) private var vm

    private let availableYears = [2023, 2024, 2025, 2026]
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date.now)
    @State private var chartAnimated = false
    @State private var selectedDate: Date?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                headerRow
                stackedSourceChart
                categoryBreakdownCard
                monthlyPivotCard
            }
            .padding(24)
        }
        .background(.clear)
        .task { await vm.loadAll() }
        .overlay {
            if vm.isLoading { LoadingOverlay(message: "Loading Revenue Analytics…") }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Revenue Analytics")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Trailing 12-month breakdown · artist & source pivot")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await vm.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise.circle.fill")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.glass).foregroundStyle(Brand.primary)
        }
    }

    // MARK: - Stacked Bar Chart by Source (mirrors SP2 pivot)

    private var stackedSourceChart: some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Revenue by Source Category")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("Streaming · Sync & Licensing · Live Performance — monthly stacked")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Legend chips
                    HStack(spacing: 12) {
                        legendChip(color: Brand.teal,    label: "Streaming")
                        legendChip(color: Brand.amber,   label: "Sync")
                        legendChip(color: Brand.emerald, label: "Live")
                    }
                }

                if vm.pivotData.isEmpty && !vm.isLoading {
                    emptyState("No pivot data available.")
                } else {
                    Chart(vm.pivotData) { pivot in
                        BarMark(
                            x: .value("Month",     pivot.month, unit: .month),
                            y: .value("Streaming", chartAnimated ? pivot.streamingAmount : 0)
                        )
                        .foregroundStyle(Brand.teal).cornerRadius(3)
                        .opacity(selectedDate == nil || Calendar.current.isDate(pivot.month, equalTo: selectedDate!, toGranularity: .month) ? 1.0 : 0.4)

                        BarMark(
                            x: .value("Month", pivot.month, unit: .month),
                            y: .value("Sync",  chartAnimated ? pivot.syncAmount : 0)
                        )
                        .foregroundStyle(Brand.amber).cornerRadius(3)
                        .opacity(selectedDate == nil || Calendar.current.isDate(pivot.month, equalTo: selectedDate!, toGranularity: .month) ? 1.0 : 0.4)

                        BarMark(
                            x: .value("Month", pivot.month, unit: .month),
                            y: .value("Live",  chartAnimated ? pivot.liveAmount : 0)
                        )
                        .foregroundStyle(Brand.emerald).cornerRadius(3)
                        .opacity(selectedDate == nil || Calendar.current.isDate(pivot.month, equalTo: selectedDate!, toGranularity: .month) ? 1.0 : 0.4)
                    }
                    .chartXSelection(value: $selectedDate)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Brand.border)
                            AxisValueLabel(format: .dateTime.month(.abbreviated), centered: false)
                                .font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { v in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Brand.border)
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text(abbreviate(d)).font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            if let selectedDate = selectedDate,
                               let xPosition = proxy.position(forX: selectedDate) {
                                // Find selected data
                                if let pivot = vm.pivotData.first(where: { Calendar.current.isDate($0.month, equalTo: selectedDate, toGranularity: .month) }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pivot.month.formatted(.dateTime.month(.wide).year()))
                                            .font(.system(size: 12, weight: .bold))
                                        Text("Stream: \(formatCurrency(pivot.streamingAmount))")
                                            .font(.system(size: 11)).foregroundStyle(Brand.teal)
                                        Text("Sync: \(formatCurrency(pivot.syncAmount))")
                                            .font(.system(size: 11)).foregroundStyle(Brand.amber)
                                        Text("Live: \(formatCurrency(pivot.liveAmount))")
                                            .font(.system(size: 11)).foregroundStyle(Brand.emerald)
                                        Text("Total: \(formatCurrency(pivot.totalAmount))")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .padding(10)
                                    .background(.regularMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .shadow(radius: 6)
                                    .position(x: xPosition, y: geo.size.height / 2)
                                    .offset(x: xPosition > geo.size.width / 2 ? -70 : 70) // Prevent going off-screen
                                }
                            }
                        }
                    }
                    .frame(height: 280)
                    .onAppear {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.72).delay(0.1)) {
                            chartAnimated = true
                        }
                    }
                    .onChange(of: vm.pivotData) { _, _ in
                        chartAnimated = false
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.72).delay(0.1)) {
                            chartAnimated = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Category Breakdown Cards

    private var categoryBreakdownCard: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
            categoryCard(
                title: "Streaming",
                amount: vm.totalStreamingRevenue,
                share: vm.totalRevenue > 0 ? vm.totalStreamingRevenue / vm.totalRevenue : 0,
                color: Brand.teal,
                icon: "waveform"
            )
            categoryCard(
                title: "Sync & Licensing",
                amount: vm.totalSyncRevenue,
                share: vm.totalRevenue > 0 ? vm.totalSyncRevenue / vm.totalRevenue : 0,
                color: Brand.amber,
                icon: "film.fill"
            )
            categoryCard(
                title: "Live Performance",
                amount: vm.totalLiveRevenue,
                share: vm.totalRevenue > 0 ? vm.totalLiveRevenue / vm.totalRevenue : 0,
                color: Brand.emerald,
                icon: "mic.fill"
            )
        }
    }

    private func categoryCard(title: String, amount: Double, share: Double, color: Color, icon: String) -> some View {
        GlassCard(cornerRadius: 20, padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                        .frame(width: 32, height: 32)
                        .background { RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color.opacity(0.15)) }
                    Spacer()
                    Text(String(format: "%.1f%%", share * 100))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(formatCurrency(amount))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(title)
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
                // Share bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Brand.border)
                        Capsule().fill(color)
                            .frame(width: geo.size.width * CGFloat(share))
                    }
                    .frame(height: 4)
                }
                .frame(height: 4)
            }
        }
    }

    // MARK: - Monthly Pivot Table

    private var monthlyPivotCard: some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Monthly Revenue Pivot", systemImage: "tablecells.fill")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Brand.primary)
                Divider().overlay(Brand.border)

                // Header
                HStack {
                    Text("Month").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Streaming").frame(width: 110, alignment: .trailing)
                    Text("Sync").frame(width: 110, alignment: .trailing)
                    Text("Live").frame(width: 110, alignment: .trailing)
                    Text("Total").frame(width: 110, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 4)

                Divider().overlay(Brand.border.opacity(0.5))

                if vm.pivotData.isEmpty && !vm.isLoading {
                    emptyState("No monthly data available.")
                } else {
                    ForEach(vm.pivotData) { pivot in
                        HStack {
                            Text(pivot.month.formatted(.dateTime.year().month(.wide)))
                                .font(.system(size: 12, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(formatCurrency(pivot.streamingAmount))
                                .font(.system(size: 12, design: .monospaced)).foregroundStyle(Brand.teal)
                                .frame(width: 110, alignment: .trailing)
                            Text(formatCurrency(pivot.syncAmount))
                                .font(.system(size: 12, design: .monospaced)).foregroundStyle(Brand.amber)
                                .frame(width: 110, alignment: .trailing)
                            Text(formatCurrency(pivot.liveAmount))
                                .font(.system(size: 12, design: .monospaced)).foregroundStyle(Brand.emerald)
                                .frame(width: 110, alignment: .trailing)
                            Text(formatCurrency(pivot.totalAmount))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .frame(width: 110, alignment: .trailing)
                        }
                        .padding(.vertical, 5).padding(.horizontal, 4)
                        .background(Color.white.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    // Grand total row
                    if !vm.pivotData.isEmpty {
                        Divider().overlay(Brand.border)
                        HStack {
                            Text("TOTAL").font(.system(size: 12, weight: .bold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(formatCurrency(vm.totalStreamingRevenue))
                                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Brand.teal)
                                .frame(width: 110, alignment: .trailing)
                            Text(formatCurrency(vm.totalSyncRevenue))
                                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Brand.amber)
                                .frame(width: 110, alignment: .trailing)
                            Text(formatCurrency(vm.totalLiveRevenue))
                                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Brand.emerald)
                                .frame(width: 110, alignment: .trailing)
                            Text(formatCurrency(vm.totalRevenue))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(Brand.primary)
                                .frame(width: 110, alignment: .trailing)
                        }
                        .padding(.vertical, 6).padding(.horizontal, 4)
                        .background(Brand.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func legendChip(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(color).frame(width: 12, height: 3)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
    }

    private func emptyState(_ msg: String) -> some View {
        Text(msg).font(.system(size: 13)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 24)
    }

    private func formatCurrency(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }

    private func abbreviate(_ v: Double) -> String {
        switch v {
        case 1_000_000...: return String(format: "$%.1fM", v / 1_000_000)
        case 1_000...:     return String(format: "$%.0fK", v / 1_000)
        default:           return String(format: "$%.0f", v)
        }
    }
}
