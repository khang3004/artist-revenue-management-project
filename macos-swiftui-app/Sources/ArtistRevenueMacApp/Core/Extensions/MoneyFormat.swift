// MoneyFormat.swift
// Amplify Core
//
// Single source of truth for currency formatting across the macOS app.
// The course project targets Vietnam, so the UI defaults to VNĐ.

import Foundation

enum AppMoney {
    static let currencyCode: String = "VND"
    static let locale: Locale = Locale(identifier: "vi_VN")

    static func format(_ value: Double, maxFractionDigits: Int = 0) -> String {
        let formatter = currencyFormatter(maxFractionDigits: maxFractionDigits)
        return formatter.string(from: NSNumber(value: value.nanSafe)) ?? "₫0"
    }

    static func formatCompact(_ value: Double) -> String {
        let safe = value.nanSafe
        let absVal = abs(safe)
        switch absVal {
        case 1_000_000_000...:
            return "₫" + decimalString(safe / 1_000_000_000, fractionDigits: 1) + "B"
        case 1_000_000...:
            return "₫" + decimalString(safe / 1_000_000, fractionDigits: 1) + "M"
        case 1_000...:
            return "₫" + decimalString(safe / 1_000, fractionDigits: 0) + "K"
        default:
            return format(safe, maxFractionDigits: 0)
        }
    }

    private static func currencyFormatter(maxFractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = maxFractionDigits
        return formatter
    }

    private static func decimalString(_ value: Double, fractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = fractionDigits
        return formatter.string(from: NSNumber(value: value.nanSafe)) ?? "0"
    }
}

extension Double {
    var moneyVND: String { AppMoney.format(self, maxFractionDigits: 0) }
    var moneyVNDCompact: String { AppMoney.formatCompact(self) }
}

