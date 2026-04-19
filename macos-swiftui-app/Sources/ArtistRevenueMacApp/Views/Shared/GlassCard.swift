// GlassCard.swift
// Amplify Core
//
// Liquid Glass container using the native macOS 26 Tahoe .glassEffect(_:in:) API.
//
// Design philosophy (Apple docs):
//   • Apply .glassEffect sparingly — only to the most important functional elements.
//   • Prefer .regular for content cards; .tinted for accent containers.
//   • Do NOT stack custom backgrounds inside glass — let the material handle depth.
//   • Wrap adjacent glass elements in GlassEffectContainer for fluid morphing.
//
// Fix (2026-04): Removed rotation3DEffect from all card variants.
// rotation3DEffect produces a degenerate perspective matrix when a view's frame
// is zero-sized during the first layout pass (common inside LazyVGrid / LazyVStack),
// which causes "passed an invalid numeric value (NaN)" CoreGraphics errors.
// A simple scaleEffect + shadow on hover is sufficient and NaN-safe.

import SwiftUI

// MARK: - GlassCard

/// A Liquid Glass content container using macOS 26's native `.glassEffect` material.
///
/// Replaces the manual `.regularMaterial` + stroke overlay approach with the system
/// `glassEffect` modifier, which provides proper optical glass properties:
/// refraction, specular highlights, shadow, and adaptive appearance.
///
/// ### Usage
/// ```swift
/// GlassCard(cornerRadius: 20) {
///     Text("Revenue: $1.2M")
/// }
/// ```
public struct GlassCard<Content: View>: View {

    private let cornerRadius: CGFloat
    private let padding:      CGFloat
    private let content:      Content

    @State private var isHovered = false

    public init(
        cornerRadius: CGFloat = 24,
        padding:      CGFloat = 24,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding      = padding
        self.content      = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            // Shadow feedback on hover — NaN-safe (no transform matrix involved)
            .shadow(
                color: isHovered ? Brand.primary.opacity(0.18) : .black.opacity(0.06),
                radius: isHovered ? 14 : 6,
                y: isHovered ? 6 : 2
            )
            // Gentle scale — safe because it never reaches 0
            .scaleEffect(isHovered ? 1.012 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - TintedGlassCard

/// An accent-tinted variant of `GlassCard` for headers, hero sections, or focused elements.
public struct TintedGlassCard<Content: View>: View {

    private let cornerRadius: CGFloat
    private let padding:      CGFloat
    private let tint:         Color
    private let content:      Content

    @State private var isHovered = false

    public init(
        cornerRadius: CGFloat = 24,
        padding:      CGFloat = 24,
        tint:         Color = Brand.primary,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding      = padding
        self.tint         = tint
        self.content      = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(tint.opacity(0.12))
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .shadow(
                color: isHovered ? tint.opacity(0.28) : .black.opacity(0.06),
                radius: isHovered ? 16 : 6,
                y: isHovered ? 6 : 2
            )
            .scaleEffect(isHovered ? 1.012 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - GlassCardModifier (Convenience Modifier)

/// Applies a Liquid Glass card effect via the `.glassCard()` modifier syntax.
public struct GlassCardModifier: ViewModifier {

    private let cornerRadius: CGFloat
    private let padding:      CGFloat

    @State private var isHovered = false

    public init(cornerRadius: CGFloat = 24, padding: CGFloat = 24) {
        self.cornerRadius = cornerRadius
        self.padding      = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .shadow(
                color: isHovered ? Brand.primary.opacity(0.18) : .black.opacity(0.06),
                radius: isHovered ? 14 : 6,
                y: isHovered ? 6 : 2
            )
            .scaleEffect(isHovered ? 1.012 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - View Extension

public extension View {

    /// Wraps the receiver in a Liquid Glass card via `.glassEffect`.
    func glassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 24) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// Wraps the receiver in a tinted Liquid Glass card.
    func tintedGlassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 24, tint: Color = Brand.primary) -> some View {
        self.padding(padding)
            .background(tint.opacity(0.12))
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}
