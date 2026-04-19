// View+NaNGuard.swift
// Amplify Core
//
// Utility extensions to sanitise geometry values before they reach CoreGraphics.
// Pass-through any numeric value through nanSafe / finiteSafe before use in
// frame(width:), frame(height:), or position(x:y:) to suppress the
// "invalid numeric value (NaN)" CoreGraphics runtime errors.

import SwiftUI

// MARK: - Numeric NaN/Infinity guards

public extension CGFloat {
    /// Returns 0 if the value is NaN or infinite; otherwise returns self.
    var nanSafe: CGFloat { (isNaN || isInfinite) ? 0 : self }

    /// Clamps to `[lo, hi]`; returns `fallback` if NaN/infinite.
    func clamped(lo: CGFloat, hi: CGFloat, fallback: CGFloat = 0) -> CGFloat {
        guard !isNaN && !isInfinite else { return fallback }
        return Swift.min(Swift.max(self, lo), hi)
    }
}

public extension Double {
    /// Returns 0 if the value is NaN or infinite; otherwise returns self.
    var nanSafe: Double { (isNaN || isInfinite) ? 0 : self }

    /// Returns `fallback` if NaN/infinite; otherwise self.
    func orZero() -> Double { nanSafe }

    /// Returns a finite non-negative value, falling back to `0` for NaN/infinity.
    var nonNegativeFinite: Double { max(0, nanSafe) }
}

// MARK: - Safe share ratio

/// Computes `numerator / denominator` safely, returning 0 on division-by-zero or NaN.
public func safeShare(_ numerator: Double, of denominator: Double) -> Double {
    guard denominator > 0, !numerator.isNaN, !denominator.isNaN else { return 0 }
    let ratio = numerator / denominator
    return ratio.isNaN || ratio.isInfinite ? 0 : min(max(ratio, 0), 1)
}
