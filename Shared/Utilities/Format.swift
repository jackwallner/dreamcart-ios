import Foundation

enum Format {
    static func coins(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// Imaginary US-dollar amount for the virtual checkout receipt. Coins map to
    /// pretend dollars at 10¢ each purely for the shopping-cart feel — no real
    /// money is involved (see the app's "everything is imaginary" disclaimer).
    static let coinToDollar = 0.10

    static func money(_ dollars: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        return f.string(from: NSNumber(value: dollars)) ?? String(format: "$%.2f", dollars)
    }

    /// Compact form for badges: 12,400 -> "12.4k".
    static func coinsShort(_ n: Int) -> String {
        if n >= 1000 {
            let k = Double(n) / 1000
            return (k >= 10 ? String(format: "%.0fk", k) : String(format: "%.1fk", k))
                .replacingOccurrences(of: ".0k", with: "k")
        }
        return "\(n)"
    }
}
