// LoadingOverlay.swift
// LabelMaster Pro — Liquid Glass loading state (macOS 26)

import SwiftUI

/// Full-coverage loading overlay with a Liquid Glass spinner pill.
/// The pill uses `.glassEffect(.regular)` — no custom material/stroke needed.
public struct LoadingOverlay: View {

    private let message: String

    @State private var rotationAngle: Double = 0
    @State private var appeared:      Bool   = false

    public init(message: String = "Loading…") {
        self.message = message
    }

    public var body: some View {
        ZStack {
            // Backdrop using system material — fine for full-coverage overlay
            Rectangle()
                .liquidGlass(in: Rectangle())
                .ignoresSafeArea()

            // Glass spinner pill
            VStack(spacing: 20) {
                // Spinner ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 2.5)
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
            // ✨ True Liquid Glass — no manual material needed
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .scaleEffect(appeared ? 1 : 0.88)
            .opacity(appeared ? 1 : 0)
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
