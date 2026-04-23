// LiquidGlassPolyfill.swift
// Amplify Core
//
// A comprehensive polyfill for the hypothetical/future macOS 26 Tahoe
// Liquid Glass APIs, gracefully degrading them to standard SwiftUI modifiers
// so the app compiles seamlessly on standard Xcode 15/16 toolchains.

import SwiftUI

// MARK: - Glass Effect Modifier

public extension View {
    /// Applies a Liquid Glass effect if available, or falls back to standard regularMaterial.
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            // Some mock toolchains intercept this, but standard compilers skip it.
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}

// MARK: - GlassEffectContainer

/// A polyfill for `GlassEffectContainer` which theoretically allows adjacent 
/// glass materials to morphically merge. On current macOS, this simply passes the content through.
public struct GlassEffectContainer<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content
    
    public init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        // Fallback: Just return the grid/stack content unmodified.
        content
    }
}

// MARK: - Background Extension Effect

public extension View {
    /// Safely wraps the SDK `backgroundExtensionEffect()` call inside a macOS 26 availability check.
    @ViewBuilder
    func liquidGlassExtensionEffect() -> some View {
        if #available(macOS 26.0, *) {
            self.backgroundExtensionEffect()
        } else {
            self
        }
    }
}

