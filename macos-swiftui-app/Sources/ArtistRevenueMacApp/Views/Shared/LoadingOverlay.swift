// LoadingOverlay.swift
// Amplify Core — Liquid Glass loading state (macOS 26)
//
// Fix (2026-04): Removed liquidGlass(in: Rectangle()) applied to the full-screen
// backdrop. A zero/indeterminate-sized rectangle passed to glassEffect/NSVisualEffectView
// produced "CGPathCloseSubpath: no current point" and NaN CoreGraphics errors at launch.
// The backdrop now uses a plain .ultraThinMaterial fill which is safe at any size.

import SwiftUI

/// Full-coverage loading overlay with a Liquid Glass spinner pill.
/// The centre pill uses `.liquidGlass` on a sized rounded rectangle — safe.
/// The backing scrim uses plain `.ultraThinMaterial` — avoids NaN at launch.
public struct LoadingOverlay: View {

    private let message: String

    @State private var rotationAngle: Double = 0
    @State private var appeared:      Bool   = false

    public init(message: String = "Loading…") {
        self.message = message
    }

    public var body: some View {
        ZStack {
            // ── Scrim ───────────────────────────────────────────────────────
            // Do NOT use liquidGlass(in: Rectangle()) here. A full-screen
            // rectangle without a fixed frame size causes CoreGraphics NaN
            // errors on first layout pass. Plain material is safe and correct.
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // ── Spinner pill ─────────────────────────────────────────────────
            VStack(spacing: 20) {
                // Spinner ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 2.5)
                        .frame(width: 48, height: 48)

                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            LinearGradient(
                                colors: [Brand.primary, Brand.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(rotationAngle))
                }

                Text(message)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 30)
            // ✨ Liquid Glass on a fixed-size pill is safe — shape has concrete bounds
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.90)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                appeared = true
            }
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}
