import Foundation

enum Format {
    static func coins(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
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
