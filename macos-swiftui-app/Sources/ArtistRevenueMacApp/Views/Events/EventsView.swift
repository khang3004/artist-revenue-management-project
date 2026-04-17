// EventsView.swift
// LabelMaster Pro
//
// Full Live Events & Venues analytics module.
// Shows venue revenue bar chart, upcoming events timeline, and sortable data table.

import SwiftUI
import Charts

struct EventsView: View {

    @Environment(EventsViewModel.self) private var vm

    private let availableYears = [2023, 2024, 2025, 2026]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                headerRow
                kpiRow
                if !vm.revenueByVenue.isEmpty { venueChartCard }
                upcomingCard
                venueTableCard
            }
            .padding(24)
        }
        .background(.clear)
        .task { await vm.load() }
        .overlay {
            if vm.isLoading { LoadingOverlay(message: "Loading Event Analytics…") }
        }
        .alert("Events Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })) {
            Button("Dismiss", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live Events & Venues")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Ticket sales, venue revenue, and artist performance analytics")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            @Bindable var bvm = vm
            Picker("Year", selection: $bvm.selectedYear) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
            .onChange(of: vm.selectedYear) { _, newYear in
                Task { await vm.changeYear(newYear) }
            }
        }
    }

    // MARK: - KPI Row

    private var kpiRow: some View {
        GlassEffectContainer(spacing: 12) {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            StatBadge(icon: "dollarsign.circle.fill",    label: "Total Live Revenue",  value: vm.formattedTotalRevenue, trend: .up,      accentColor: Brand.emerald)
            StatBadge(icon: "ticket.fill",               label: "Total Tickets Sold",  value: "\(vm.totalTicketsSold.formatted())",       trend: .neutral, accentColor: Brand.amber)
            StatBadge(icon: "building.2.crop.circle",    label: "Top Venue",           value: vm.topVenue,             trend: .neutral, accentColor: Brand.teal)
        }
        }
    }

    // MARK: - Venue Revenue Bar Chart

    private var venueChartCard: some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Revenue by Venue")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("Live performance gross revenue per venue · \(vm.selectedYear)")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Chart(vm.revenueByVenue, id: \.venue) { item in
                    BarMark(
                        x: .value("Revenue", item.revenue),
                        y: .value("Venue",   item.venue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Brand.emerald, Brand.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
                    .annotation(position: .trailing) {
                        Text(abbreviate(item.revenue))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Brand.border)
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(abbreviate(d)).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().font(.system(size: 11))
                    }
                }
                .frame(height: CGFloat(max(200, vm.revenueByVenue.count * 44)))
            }
        }
    }

    // MARK: - Upcoming Events Timeline

    private var upcomingCard: some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Upcoming Events", systemImage: "calendar.badge.clock")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Brand.primary)
                    Spacer()
                    Text("\(vm.upcomingEvents.count) scheduled")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Divider().overlay(Brand.border)

                if vm.upcomingEvents.isEmpty {
                    Text("No upcoming events scheduled.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 16)
                } else {
                    ForEach(vm.upcomingEvents.prefix(8)) { event in
                        upcomingEventRow(event)
                        if event.id != vm.upcomingEvents.prefix(8).last?.id {
                            Divider().padding(.leading, 46).overlay(Brand.border.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private func upcomingEventRow(_ event: Event) -> some View {
        HStack(spacing: 12) {
            // Date bubble
            VStack(spacing: 1) {
                Text(event.eventDate.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
                Text(event.eventDate.formatted(.dateTime.day()))
                    .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(Brand.primary)
            }
            .frame(width: 38)
            .padding(6)
            .background { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.primary.opacity(0.10)) }

            VStack(alignment: .leading, spacing: 3) {
                Text(event.eventName)
                    .font(.system(size: 13, weight: .medium)).lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(event.venueName ?? "Venue TBD")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(event.eventDate.formatted(.dateTime.hour().minute()))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Venue Data Table

    private var venueTableCard: some View {
        GlassCard(cornerRadius: 24, padding: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Venue Analytics Detail", systemImage: "tablecells")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Brand.primary)
                    Spacer()
                    Text("\(vm.filteredVenueRows.count) rows")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Divider().overlay(Brand.border)

                // Column headers
                HStack {
                    Text("Venue").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Artist").frame(width: 130, alignment: .leading)
                    Text("Events").frame(width: 60, alignment: .trailing)
                    Text("Tickets").frame(width: 70, alignment: .trailing)
                    Text("Revenue").frame(width: 100, alignment: .trailing)
                    Text("Rank").frame(width: 50, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

                Divider().overlay(Brand.border.opacity(0.6))

                ForEach(vm.filteredVenueRows) { row in
                    HStack {
                        Text(row.venueName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.artistName)
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .lineLimit(1).frame(width: 130, alignment: .leading)
                        Text("\(row.eventCount)")
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 60, alignment: .trailing)
                        Text("\(row.ticketsSold.formatted())")
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 70, alignment: .trailing)
                        Text(row.formattedRevenue)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Brand.emerald)
                            .frame(width: 100, alignment: .trailing)
                        Text("#\(row.venueRank)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(row.venueRank <= 3 ? Brand.primary : .secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 4)
                    .background(Color.white.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
    }

    private func abbreviate(_ v: Double) -> String {
        switch v {
        case 1_000_000...: return String(format: "$%.1fM", v / 1_000_000)
        case 1_000...:     return String(format: "$%.0fK", v / 1_000)
        default:           return String(format: "$%.0f", v)
        }
    }
}
