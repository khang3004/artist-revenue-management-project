// GlassCard.swift
// LabelMaster Pro
//
// Liquid Glass container using the native macOS 26 Tahoe .glassEffect(_:in:) API.
//
// Design philosophy (Apple docs):
//   • Apply .glassEffect sparingly — only to the most important functional elements.
//   • Prefer .regular for content cards; .tinted for accent containers.
//   • Do NOT stack custom backgrounds inside glass — let the material handle depth.
//   • Wrap adjacent glass elements in GlassEffectContainer for fluid morphing.

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

    public init(
        cornerRadius: CGFloat = 20,
        padding:      CGFloat = 20,
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
    }
}

// MARK: - TintedGlassCard

/// An accent-tinted variant of `GlassCard` for headers, hero sections, or focused elements.
/// Uses `.tinted` glass which adds a subtle brand color wash to the glass material.
public struct TintedGlassCard<Content: View>: View {

    private let cornerRadius: CGFloat
    private let padding:      CGFloat
    private let tint:         Color
    private let content:      Content

    public init(
        cornerRadius: CGFloat = 20,
        padding:      CGFloat = 20,
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
            .background(tint.opacity(0.15))
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

// MARK: - GlassCardModifier (Convenience Modifier)

/// Applies a Liquid Glass card effect via the `.glassCard()` modifier syntax.
public struct GlassCardModifier: ViewModifier {

    private let cornerRadius: CGFloat
    private let padding:      CGFloat

    public init(cornerRadius: CGFloat = 20, padding: CGFloat = 20) {
        self.cornerRadius = cornerRadius
        self.padding      = padding
    }

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}

// MARK: - View Extension

public extension View {

    /// Wraps the receiver in a Liquid Glass card via `.glassEffect`.
    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    /// Wraps the receiver in a tinted Liquid Glass card.
    func tintedGlassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 20, tint: Color = Brand.primary) -> some View {
        self.padding(padding)
            .background(tint.opacity(0.15))
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }
}
