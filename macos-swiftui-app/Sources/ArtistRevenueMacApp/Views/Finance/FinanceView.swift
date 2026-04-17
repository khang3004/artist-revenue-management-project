// FinanceView.swift
// LabelMaster Pro
//
// Finance & Contracts module: contract payout table (SP4),
// top tracks per artist chart (SP5), and wallet audit report (SP6).

import SwiftUI
import Charts

struct FinanceView: View {

    @Environment(FinanceViewModel.self) private var vm

    private let availableYears = [2023, 2024, 2025, 2026]
    private let topNOptions    = [3, 5, 10]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                headerRow
                kpiRow
                contractPayoutsCard
                topTracksCard
                walletAuditCard
            }
            .padding(24)
        }
        .background(.clear)
        .task { await vm.loadAll() }
        .overlay {
            if vm.isLoading { LoadingOverlay(message: "Loading Finance Intelligence…") }
        }
        .alert("Finance Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("Dismiss", role: .cancel) { vm.errorMessage = nil }
            Button("Retry") { Task { await vm.refresh() } }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Finance & Contracts")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Contract revenue splits · Top tracks · Wallet audit reconciliation")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                @Bindable var bvm = vm
                Picker("Year", selection: $bvm.selectedYear) {
                    ForEach(availableYears, id: \.self) { Text(String($0)).tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 240)
                .onChange(of: vm.selectedYear) { _, _ in Task { await vm.reloadTracks() } }

                Picker("Top N", selection: $bvm.selectedTopN) {
                    ForEach(topNOptions, id: \.self) { Text("Top \($0)").tag($0) }
                }
                .pickerStyle(.segmented).frame(width: 160)
                .onChange(of: vm.selectedTopN) { _, _ in Task { await vm.reloadTracks() } }
            }
        }
    }

    // MARK: - KPI Row

    private var kpiRow: some View {
        GlassEffectContainer(spacing: 12) {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            StatBadge(icon: "doc.richtext.fill",    label: "Total Contract Payouts", value: vm.formattedTotalPayouts,        trend: .neutral, accentColor: Brand.primary)
            StatBadge(icon: "exclamationmark.triangle.fill", label: "Wallet Warnings",  value: "\(vm.warningArtistCount) artists", trend: vm.warningArtistCount > 0 ? .down : .neutral, accentColor: Brand.rose)
            StatBadge(icon: "arrow.up.circle.fill", label: "Pending Withdrawals", value: vm.formattedPendingWithdrawals, trend: .neutral, accentColor: Brand.amber)
        }
        }
    }

    // MARK: - Contract Payouts (SP4)

    private var contractPayoutsCard: some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Contract Revenue Distribution", systemImage: "doc.text.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Brand.primary)
                    Spacer()
                    Text("\(vm.contractPayouts.count) splits")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Divider().overlay(Brand.border)

                if !vm.payoutByBeneficiaryType.isEmpty {
                    HStack(spacing: 16) {
                        ForEach(vm.payoutByBeneficiaryType, id: \.type) { item in
                            VStack(spacing: 4) {
                                Text(formatCurrency(item.total))
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(item.type == "Artist" ? Brand.primary : Brand.teal)
                                Text(item.type)
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.primary.opacity(0.07)) }
                        }
                        Spacer()
                    }
                    .padding(.bottom, 4)
                }

                // Column headers
                payoutTableHeader
                Divider().overlay(Brand.border.opacity(0.5))
                ForEach(vm.contractPayouts.prefix(30)) { row in
                    payoutRow(row)
                }
                if vm.contractPayouts.count > 30 {
                    Text("Showing first 30 of \(vm.contractPayouts.count) splits.")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var payoutTableHeader: some View {
        HStack {
            Text("Contract").frame(maxWidth: .infinity, alignment: .leading)
            Text("Track").frame(width: 130, alignment: .leading)
            Text("Beneficiary").frame(width: 110, alignment: .leading)
            Text("Type").frame(width: 55, alignment: .leading)
            Text("Share").frame(width: 55, alignment: .trailing)
            Text("Payout").frame(width: 85, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    private func payoutRow(_ row: ContractPayoutRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.contractName).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text(row.contractStatus.capitalized).font(.system(size: 9)).foregroundStyle(
                    row.contractStatus == "active" ? Brand.emerald : .secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)

            Text(row.trackTitle).font(.system(size: 11)).lineLimit(1)
                .frame(width: 130, alignment: .leading)
            Text(row.beneficiary).font(.system(size: 11)).lineLimit(1).foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(row.beneficiaryType).font(.system(size: 10, weight: .medium))
                .foregroundStyle(row.beneficiaryType == "Artist" ? Brand.primary : Brand.teal)
                .frame(width: 55, alignment: .leading)

            Text(row.formattedShare).font(.system(size: 11, design: .monospaced))
                .frame(width: 55, alignment: .trailing)
            Text(row.formattedPayout).font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Brand.primary)
                .frame(width: 85, alignment: .trailing)
        }
        .padding(.vertical, 5).padding(.horizontal, 4)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Top Tracks Chart (SP5)

    private var topTracksCard: some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Top Tracks per Artist")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("By revenue · \(vm.selectedYear) · Top \(vm.selectedTopN) per artist")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if vm.topTracksForChart.isEmpty && !vm.isLoading {
                    Text("No track data available for \(vm.selectedYear).")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 24)
                } else {
                    Chart(vm.topTracksForChart) { row in
                        BarMark(
                            x: .value("Revenue", row.totalRevenue),
                            y: .value("Track", "\(row.artistName) · \(row.trackTitle)")
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [Brand.primary, Brand.secondary],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .cornerRadius(5)
                        .annotation(position: .trailing) {
                            Text(abbreviate(row.totalRevenue))
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartXAxis {
                        AxisMarks { v in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Brand.border)
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text(abbreviate(d)).font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 10)) } }
                    .frame(height: CGFloat(max(200, vm.topTracksForChart.count * 36)))
                }
            }
        }
    }

    // MARK: - Wallet Audit (SP6)

    private var walletAuditCard: some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Wallet Audit Report", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Brand.primary)
                    Spacer()
                    if vm.warningArtistCount > 0 {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("\(vm.warningArtistCount) discrepanc\(vm.warningArtistCount == 1 ? "y" : "ies")")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Brand.rose)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background { Capsule().fill(Brand.rose.opacity(0.12)) }
                    } else if !vm.walletAudit.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("All wallets balanced")
                        }
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Brand.emerald)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background { Capsule().fill(Brand.emerald.opacity(0.12)) }
                    }
                }
                Divider().overlay(Brand.border)

                // Column headers
                HStack {
                    Text("Artist").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Label").frame(width: 100, alignment: .leading)
                    Text("Genre").frame(width: 80, alignment: .leading)
                    Text("Balance").frame(width: 90, alignment: .trailing)
                    Text("Earned").frame(width: 90, alignment: .trailing)
                    Text("Withdrawn").frame(width: 90, alignment: .trailing)
                    Text("Pending").frame(width: 85, alignment: .trailing)
                    Text("Δ").frame(width: 80, alignment: .trailing)
                    Text("Status").frame(width: 70, alignment: .center)
                }
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 4)

                Divider().overlay(Brand.border.opacity(0.5))

                ForEach(vm.walletAudit) { row in
                    auditRow(row)
                }

                if vm.walletAudit.isEmpty && !vm.isLoading {
                    Text("No wallet data found.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 16)
                }
            }
        }
    }

    private func auditRow(_ row: WalletAuditRow) -> some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Brand.primary.opacity(0.14)).frame(width: 26, height: 26)
                    Text(String(row.artistName.prefix(1)).uppercased())
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(Brand.primary)
                }
                Text(row.artistName).font(.system(size: 12, weight: .medium)).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)

            Text(row.labelName ?? "—").font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(1).frame(width: 100, alignment: .leading)
            Text(row.genre ?? "—").font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(1).frame(width: 80, alignment: .leading)

            Text(row.formattedBalance)
                .font(.system(size: 11, design: .monospaced)).frame(width: 90, alignment: .trailing)
            Text(formatCurrency(row.totalEarned))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(Brand.emerald)
                .frame(width: 90, alignment: .trailing)
            Text(formatCurrency(row.totalWithdrawn))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Text(formatCurrency(row.pendingWithdrawal))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(Brand.amber)
                .frame(width: 85, alignment: .trailing)

            // Discrepancy — colour-coded
            Text(row.formattedDiscrepancy)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(abs(row.discrepancy) < 0.01 ? Brand.emerald : Brand.rose)
                .frame(width: 80, alignment: .trailing)

            // Status badge
            Text(row.auditStatus)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(row.isHealthy ? Brand.emerald : Brand.rose)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background { Capsule().fill(row.isHealthy ? Brand.emerald.opacity(0.12) : Brand.rose.opacity(0.12)) }
                .frame(width: 70, alignment: .center)
        }
        .padding(.vertical, 5).padding(.horizontal, 4)
        .background(row.isHealthy ? Color.clear : Brand.rose.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - Helpers
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
