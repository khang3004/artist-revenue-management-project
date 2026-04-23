// ContractTimelineView.swift
// Amplify Core
//
// A detailed charting view displaying a Gantt-style timeline of an artist's contracts.
//
// Fix (2026-04): Added explicit height floor (max(150, ...)) already existed, but the
// BarMark endDate fallback used an implicitly-unwrapped optional that could produce an
// invalid date path if `Calendar.current.date(byAdding:)` returns nil (rare but possible).
// The fallback is now coalesced to a safe 5-year future date constant.
// Also added `.frame(minHeight: 150)` to prevent a 0-height chart frame.

import SwiftUI
import Charts

// A concrete far-future date used as a safe open-ended contract end
private let openEndFallback: Date = {
    Calendar.current.date(byAdding: .year, value: 5, to: Date.now) ?? Date(timeIntervalSinceNow: 5 * 365 * 24 * 3600)
}()

struct ContractTimelineView: View {

    let contracts: [Contract]

    var body: some View {
        GlassCard(cornerRadius: 20, padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Contract Lifecycle Timeline", systemImage: "clock.arrow.2.circlepath")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(Brand.primary)

                if contracts.isEmpty {
                    Text("No contracts associated with this artist.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Chart {
                        ForEach(contracts) { contract in
                            // Use the precomputed constant rather than an !-forced optional
                            let safeEnd = contract.endDate ?? openEndFallback
                            BarMark(
                                xStart: .value("Start", contract.startDate),
                                xEnd:   .value("End",   safeEnd),
                                y:      .value("Contract", contract.name)
                            )
                            .foregroundStyle(colorFor(contract.contractType).gradient)
                            .cornerRadius(6)
                            .annotation(position: .overlay, alignment: .leading) {
                                Text(contract.contractType.displayName)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(preset: .aligned, values: .stride(by: .year)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4])).foregroundStyle(Brand.border)
                            AxisValueLabel(format: .dateTime.year(), centered: true)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    // Explicit floor + ceiling to guarantee CoreGraphics always
                    // receives a positive, finite height value.
                    .frame(minHeight: 150, idealHeight: max(150, CGFloat(contracts.count * 52)))
                }
            }
        }
    }

    private func colorFor(_ type: ContractType) -> Color {
        switch type {
        case .recording:    return Brand.amber
        case .distribution: return Brand.emerald
        case .publishing:   return Brand.teal
        }
    }
}
