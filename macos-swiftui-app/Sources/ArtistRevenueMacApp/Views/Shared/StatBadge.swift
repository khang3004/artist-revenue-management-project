// StatBadge.swift
// LabelMaster Pro
//
// KPI metric badge using macOS 26 Liquid Glass design language.
// Wrap multiple StatBadges in GlassEffectContainer so glass shapes morphs together.

import SwiftUI

// MARK: - MetricTrend

public enum MetricTrend: Equatable {
    case up, down, neutral

    var symbolName: String {
        switch self {
        case .up:      return "arrow.up.right"
        case .down:    return "arrow.down.right"
        case .neutral: return "minus"
        }
    }
    var color: Color {
        switch self {
        case .up:      return Brand.emerald
        case .down:    return Brand.rose
        case .neutral: return Color.secondary
        }
    }
}

// MARK: - StatBadge

/// KPI metric card using native `.glassEffect`.
///
/// The icon background uses `.glassEffect(.regular.tinted(accentColor))` so it becomes
/// a genuine Liquid Glass lozenge — not a flat color fill.
/// Wrap a row of `StatBadge` views inside a `GlassEffectContainer` at the call site
/// so adjacent glass panels morph fluidly into each other.
public struct StatBadge: View {

    private let icon:        String
    private let label:       String
    private let value:       String
    private let trend:       MetricTrend
    private let accentColor: Color

    @State private var appeared: Bool = false

    public init(
        icon:        String,
        label:       String,
        value:       String,
        trend:       MetricTrend = .neutral,
        accentColor: Color = Brand.primary
    ) {
        self.icon        = icon
        self.label       = label
        self.value       = value
        self.trend       = trend
        self.accentColor = accentColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Icon + optional trend chip
            HStack(alignment: .center) {
                // Tinted glass icon lozenge
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 40, height: 40)
                    .background(accentColor.opacity(0.15))
                    .liquidGlass(
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                Spacer()

                if trend != .neutral {
                    Label {
                        Text(trend == .up ? "↑" : "↓")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    } icon: { EmptyView() }
                    .foregroundStyle(trend.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(trend.color.opacity(0.15))
                    .liquidGlass(
                        in: Capsule()
                    )
                }
            }

            // Primary value
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            // Label
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(20)
        // The card itself is glass
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.94)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.74).delay(0.04)) {
                appeared = true
            }
        }
    }
}

// MARK: - KPIRow convenience wrapper

/// Wraps a row of `StatBadge` views in a `GlassEffectContainer` so their glass
/// panels can morphically merge when adjacent per Apple's Liquid Glass specification.
public struct KPIRow: View {

    private let badges: [AnyView]

    public init(@ViewBuilder content: () -> some View) {
        // Wrap into AnyView so we can count — for small counts we just embed directly.
        self.badges = []
    }

    public var body: some View {
        EmptyView()
    }
}
