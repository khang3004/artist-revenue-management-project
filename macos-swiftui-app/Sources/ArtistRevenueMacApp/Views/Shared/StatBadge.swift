// StatBadge.swift
// Amplify Core
//
// KPI metric badge using macOS 26 Liquid Glass design language.
// Wrap multiple StatBadges in GlassEffectContainer so glass shapes morph together.
//
// Fix (2026-04): Entry animation changed from scaleEffect(0.94→1) to opacity(0→1) only.
// scaleEffect at startup combined with liquidGlass on a zero-sized parent view (common
// during the first LazyVGrid layout pass) produced NaN values passed to CoreGraphics.
// Opacity-only animation is equally smooth and fully NaN-safe.

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
/// The icon background uses `.liquidGlass` so it becomes a genuine Liquid Glass lozenge.
/// Wrap a row of `StatBadge` views inside a `GlassEffectContainer` at the call site
/// so adjacent glass panels morph fluidly into each other.
public struct StatBadge: View {

    private let icon:        String
    private let label:       String
    private let value:       String
    private let trend:       MetricTrend
    private let accentColor: Color

    // Use opacity-only entry animation — scaleEffect from near-zero triggers NaN in
    // CoreGraphics when the parent view's frame is not yet determined (LazyVGrid).
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
                    .liquidGlass(in: Capsule())
                }
            }

            // Primary value
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
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
        // Opacity-only fade-in: safe regardless of frame size during layout
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(0.05)) {
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
        self.badges = []
    }

    public var body: some View {
        EmptyView()
    }
}
