import Foundation

/// Count labels shown beside a number that is drawn separately ("18,450" above
/// "Coins"). A catalog plural variant has to contain its number, so these labels
/// cannot be plural keys themselves. Instead the catalog's `"%lld plural category"`
/// key returns the CLDR category for the user's language ("few 3"), and each
/// label has one whole key per category.
enum PluralLabel {
    enum Category: String {
        case one, few, many, other
    }

    static func category(_ count: Int) -> Category {
        let token = String(localized: "\(count) plural category")
        let word = token.split(separator: " ").first.map(String.init) ?? ""
        return Category(rawValue: word) ?? (count == 1 ? .one : .other)
    }

    /// "Coins", on the You tab's stat tile. English has one wording, so its
    /// `(one)` key reads the same.
    static func coins(_ count: Int) -> String {
        switch category(count) {
        case .one: String(localized: "Coins (one)")
        case .few: String(localized: "Coins (few)")
        case .many: String(localized: "Coins (many)")
        case .other: String(localized: "Coins")
        }
    }
}
