// Color+Brand.swift
// LabelMaster Pro
//
// Brand colour tokens calibrated for macOS 26 Liquid Glass.
//
// Design notes:
//   • Glass refracts and tints based on the colour BEHIND it.
//   • Use vivid, saturated hues so the .tinted() glass effect reads clearly.
//   • Dark background shades ensure glass highlights pop with refracted light.
//   • Never apply these colours as opaque fills on top of glass —
//     they serve as the substrate the glass refracts FROM.

import SwiftUI

public enum Brand {

    // MARK: - Primary Accent Palette
    //   Vivid and saturated — designed to pop through the glass material.

    /// Deep violet — primary interactive accent. Picked up by .tinted() glass.
    public static let primary:   Color = Color(hue: 0.720, saturation: 0.82, brightness: 0.95)

    /// Electric indigo — secondary accent for gradient end-points.
    public static let secondary: Color = Color(hue: 0.655, saturation: 0.88, brightness: 1.00)

    /// Warm rose — alert indicators, negative trend arrows.
    public static let rose:      Color = Color(hue: 0.950, saturation: 0.78, brightness: 0.98)

    /// Cyan-teal — Streaming revenue.
    public static let teal:      Color = Color(hue: 0.510, saturation: 0.76, brightness: 0.88)

    /// Warm amber — Sync & Licensing revenue.
    public static let amber:     Color = Color(hue: 0.102, saturation: 0.92, brightness: 1.00)

    /// Emerald — Live Performance revenue, positive indicators.
    public static let emerald:   Color = Color(hue: 0.388, saturation: 0.72, brightness: 0.82)

    // MARK: - Mesh Gradient Backdrop
    //   These form the rich coloured canvas beneath the glass layers.
    //   Glass picks up and refracts these hues to create the optical glass effect.

    public static let meshStart: Color = Color(hue: 0.720, saturation: 0.60, brightness: 0.15)
    public static let meshMid:   Color = Color(hue: 0.660, saturation: 0.65, brightness: 0.12)
    public static let meshEnd:   Color = Color(hue: 0.600, saturation: 0.50, brightness: 0.10)

    // MARK: - Semantic Tokens (used for minor separators / axis grid lines)

    /// Subtle separator colour — for chart grid lines and Dividers.
    public static let border: Color = Color.secondary.opacity(0.18)
}
