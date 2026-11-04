import Foundation

/// Locale-aware rendering of coin amounts. In US English the output matches the
/// app's wording ("1,000", "12.4k", "+500"); other locales get their own forms
/// from Foundation.
enum DisplayFormat {
    /// "1,000"
    static func coins(_ n: Int) -> String {
        n.formatted(.number)
    }

    /// "+500", "-500", "0"
    static func signedCoins(_ n: Int) -> String {
        n.formatted(.number.sign(strategy: .always(includingZero: false)))
    }

    /// Compact form for badges: 12,400 -> "12k", 3,200 -> "3.2k".
    static func coinsShort(_ n: Int) -> String {
        guard n >= 1000 else { return n.formatted(.number) }
        let k = Double(n) / 1000
        let digits = k >= 10 ? 0...0 : 0...1
        let number = k.formatted(.number.grouping(.never).precision(.fractionLength(digits)))
        return String(localized: "\(number)k")
    }
}
