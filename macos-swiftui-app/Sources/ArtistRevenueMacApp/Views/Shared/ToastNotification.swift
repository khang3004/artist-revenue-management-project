// ToastNotification.swift
// Amplify Core
//
// Reusable toast notification system for transient feedback (success, error, info)
// displayed as a floating Liquid Glass pill at the bottom of the screen.
// Usage: call ToastManager.shared.show(...) from any context.

import SwiftUI

// MARK: - Toast Model

public enum ToastStyle {
    case success, error, warning, info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .success: return Brand.emerald
        case .error:   return Brand.rose
        case .warning: return Brand.amber
        case .info:    return Brand.primary
        }
    }
}

public struct ToastMessage: Identifiable, Equatable {
    public let id = UUID()
    public let message: String
    public let style:   ToastStyle
    public let duration: TimeInterval

    public init(_ message: String, style: ToastStyle = .info, duration: TimeInterval = 3) {
        self.message  = message
        self.style    = style
        self.duration = duration
    }
}

// MARK: - ToastManager

@Observable
@MainActor
public final class ToastManager {
    public static let shared = ToastManager()
    private init() {}

    var current: ToastMessage? = nil
    private var dismissTask: Task<Void, Never>?

    public func show(_ message: String, style: ToastStyle = .info, duration: TimeInterval = 3) {
        current = ToastMessage(message, style: style, duration: duration)
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled { current = nil }
        }
    }

    public func dismiss() { current = nil; dismissTask?.cancel() }
}

// MARK: - ToastOverlay View Modifier

struct ToastOverlayModifier: ViewModifier {
    @State private var manager = ToastManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = manager.current {
                    ToastPill(toast: toast)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal:   .opacity
                        ))
                        .padding(.bottom, 28)
                        .onTapGesture { manager.dismiss() }
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: manager.current?.id)
    }
}

// MARK: - ToastPill

private struct ToastPill: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.style.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(toast.style.color)

            Text(toast.message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .liquidGlass(in: Capsule())
        .shadow(color: toast.style.color.opacity(0.2), radius: 10, y: 4)
    }
}

// MARK: - View Extension

public extension View {
    /// Adds a toast overlay to this view. Apply once at the root content view.
    func toastOverlay() -> some View {
        modifier(ToastOverlayModifier())
    }
}
