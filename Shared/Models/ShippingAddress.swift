import Foundation

/// A pretend delivery address for the fake checkout. Purely flavor for the
/// dopamine-shopping loop — nothing ever ships — but it's validated and
/// formatted like a real ecomm shipping address so checkout feels real.
struct ShippingAddress: Codable, Equatable, Sendable {
    var name = ""
    var line1 = ""
    var line2 = ""
    var city = ""
    var state = ""
    var zip = ""
    var country = "United States"

    /// Light validation: name, street, and city must be filled in. Line 2,
    /// state, zip, and country are all optional so the form never feels
    /// bureaucratic.
    var isValid: Bool {
        [name, line1, city].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// True when nothing meaningful has been filled in yet, so the You tab and
    /// checkout can tell "never set" apart from "set but incomplete."
    var isEmpty: Bool {
        [name, line1, line2, city, state, zip].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Multi-line "Ships to" block shown on the checkout summary.
    var multilineSummary: String {
        var lines = [name, line1]
        let trimmedLine2 = line2.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLine2.isEmpty { lines.append(line2) }
        let cityState = [city, state].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: ", ")
        let cityStateZip = [cityState, zip].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: " ")
        if !cityStateZip.trimmingCharacters(in: .whitespaces).isEmpty { lines.append(cityStateZip) }
        let trimmedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCountry.isEmpty { lines.append(country) }
        return lines
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }
}
