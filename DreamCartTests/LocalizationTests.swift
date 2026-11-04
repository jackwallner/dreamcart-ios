import Foundation
import XCTest

/// The string catalog compiles into en.lproj, and its plural and substitution
/// values keep the English wording. A key that fell through would still pass a
/// "not empty" check, so these compare against the visible copy.
final class LocalizationTests: XCTestCase {
    private func enBundle() throws -> Bundle {
        for host in [Bundle.main, Bundle(for: LocalizationTests.self)] + Bundle.allBundles {
            if let path = host.path(forResource: "en", ofType: "lproj"),
               FileManager.default.fileExists(atPath: path + "/Localizable.strings"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return try XCTUnwrap(nil as Bundle?, "en.lproj/Localizable.strings is missing")
    }

    func testPluralsKeepEnglishWording() throws {
        let en = try enBundle()
        XCTAssertEqual(String(localized: "\(1) pieces delivered to your closet", bundle: en), "1 piece delivered to your closet")
        XCTAssertEqual(String(localized: "\(4) pieces delivered to your closet", bundle: en), "4 pieces delivered to your closet")
        XCTAssertEqual(String(localized: "\(1) pieces owned", bundle: en), "1 piece owned")
        XCTAssertEqual(String(localized: "\(4) pieces owned", bundle: en), "4 pieces owned")
        XCTAssertEqual(String(localized: "\(1) pieces", bundle: en), "1 piece")
        XCTAssertEqual(String(localized: "\(4) pieces", bundle: en), "4 pieces")
        XCTAssertEqual(String(localized: "\(1) items", bundle: en), "1 item")
        XCTAssertEqual(String(localized: "\(4) items", bundle: en), "4 items")
        XCTAssertEqual(String(localized: "\(1) days", bundle: en), "1 day")
        XCTAssertEqual(String(localized: "\(4) days", bundle: en), "4 days")
        XCTAssertEqual(String(localized: "Streak \(1) days. Come back tomorrow for more.", bundle: en), "Streak 1 day. Come back tomorrow for more.")
        XCTAssertEqual(String(localized: "Streak \(4) days. Come back tomorrow for more.", bundle: en), "Streak 4 days. Come back tomorrow for more.")
    }

    /// These counts had no singular wording before the catalog, so English still has none.
    func testCountsWithOneWordingStayAsTheyWere() throws {
        let en = try enBundle()
        XCTAssertEqual(String(localized: "\(1) coins", bundle: en), "1 coins")
        XCTAssertEqual(String(localized: "\(1) picks", bundle: en), "1 picks")
        XCTAssertEqual(String(localized: "You need \(1) more coins", bundle: en), "You need 1 more coins")
        XCTAssertEqual(String(localized: "\(1)-day streak", bundle: en), "1-day streak")
        XCTAssertEqual(String(localized: "Start \(3)-day free trial", bundle: en), "Start 3-day free trial")
    }

    /// Coin amounts used to be grouped by hand before they were spliced in.
    func testCoinCountsStayGrouped() throws {
        let en = try enBundle()
        XCTAssertEqual(String(localized: "\(3200) coins", bundle: en), "3,200 coins")
        XCTAssertEqual(String(localized: "You need \(1500) more coins", bundle: en), "You need 1,500 more coins")
        XCTAssertEqual(String(localized: "You won \(1500) coins", bundle: en), "You won 1,500 coins")
    }

    func testSubstitutionsKeepEnglishWording() throws {
        let en = try enBundle()
        XCTAssertEqual(String(localized: "\("Halo Coat"), \(1200) coins, \("Rare")", bundle: en), "Halo Coat, 1,200 coins, Rare")
        XCTAssertEqual(String(localized: "\("Coins added"), \(3200) coins. \("Enjoy the shop.")", bundle: en), "Coins added, 3,200 coins. Enjoy the shop.")
        XCTAssertEqual(String(localized: "\("Halo Coat"), \("Après"), \("Rare"), \(1200) coins", bundle: en), "Halo Coat, Après, Rare, 1,200 coins")
        XCTAssertEqual(String(localized: "Get \(3200) coins for \("$4.99")", bundle: en), "Get 3,200 coins for $4.99")
        XCTAssertEqual(String(localized: "\(3) days free, then \("$0.99") per week. Auto-renews until canceled. Cancel anytime in Settings.", bundle: en),
                       "3 days free, then $0.99 per week. Auto-renews until canceled. Cancel anytime in Settings.")
        XCTAssertEqual(String(localized: "\(3) days free, then a weekly charge. Auto-renews until canceled.", bundle: en),
                       "3 days free, then a weekly charge. Auto-renews until canceled.")
    }

    func testMultiArgumentKeysKeepTheirOrder() throws {
        let en = try enBundle()
        XCTAssertEqual(String(localized: "Page \(1) of \(3)", bundle: en), "Page 1 of 3")
        XCTAssertEqual(String(localized: "\("Après"), \("Halo Coat")", bundle: en), "Après, Halo Coat")
        XCTAssertEqual(String(localized: "\("Daily claimed"). \("More tomorrow")", bundle: en), "Daily claimed. More tomorrow")
        XCTAssertEqual(String(localized: "Server error \(500): \("boom")", bundle: en), "Server error 500: boom")
    }

    /// Display words that used to come from `.capitalized` or `.uppercased()`.
    func testWholeKeysMatchTheTextTheyReplaced() {
        let rarities: [Rarity] = [.common, .rare, .epic, .legendary]
        for rarity in rarities {
            XCTAssertEqual(rarity.label, rarity.rawValue.capitalized)
            XCTAssertEqual(rarity.badgeLabel, rarity.rawValue.capitalized.uppercased())
        }
    }

    /// Logic that used to read a pack's display text now reads its id or badge case.
    func testCoinPacksKeepTheirWording() {
        XCTAssertEqual(CoinPack.all.map(\.title), ["Pocket", "Bag", "Haul", "Spree", "Vault"])
        XCTAssertEqual(CoinPack.all.compactMap(\.badge?.label), ["POPULAR", "BEST VALUE"])
        XCTAssertEqual(CoinPack.recommended.productId, "com.jackwallner.shop.coins.bag")
    }

    func testCountLabelsDrawnBesideANumberPickByCategory() {
        XCTAssertEqual(PluralLabel.category(1), .one)
        XCTAssertEqual(PluralLabel.category(5), .other)
        XCTAssertEqual(PluralLabel.coins(1), "Coins")
        XCTAssertEqual(PluralLabel.coins(18_450), "Coins")
    }

    func testFormattersKeepUSEnglish() throws {
        try XCTSkipUnless(Locale.current.identifier == "en_US", "US English wording only")
        XCTAssertEqual(DisplayFormat.signedCoins(500), "+500")
        XCTAssertEqual(DisplayFormat.signedCoins(1500), "+1,500")
        XCTAssertEqual(DisplayFormat.signedCoins(-500), "-500")
        XCTAssertEqual(DisplayFormat.signedCoins(0), "0")
        XCTAssertEqual(DisplayFormat.coinsShort(1500), "1.5k")
        XCTAssertEqual(DisplayFormat.coinsShort(25_000), "25k")
    }

    static let languages = ["ar", "de", "es", "ja", "pt-BR", "ru", "tr", "zh-Hans"]

    private func bundle(_ language: String) throws -> Bundle {
        for host in [Bundle.main, Bundle(for: LocalizationTests.self)] + Bundle.allBundles {
            if let path = host.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return try XCTUnwrap(nil as Bundle?, "\(language).lproj is missing")
    }

    func testEveryLanguageTranslatesThePlurals() throws {
        for language in Self.languages {
            let host = try bundle(language)
            let text = String(localized: "\(4) pieces owned", bundle: host, locale: Locale(identifier: language))
            XCTAssertFalse(text.contains("#@"), "\(language): \(text)")
            XCTAssertNotEqual(text, "4 pieces owned", language)
            XCTAssertTrue(text.contains("4") || text.contains("٤"), "\(language): \(text)")
        }
    }

    func testRussianPicksPluralCategories() throws {
        let russian = try bundle("ru")
        let locale = Locale(identifier: "ru")
        let forms = [1, 3, 5].map { String(localized: "\($0) items", bundle: russian, locale: locale) }
        XCTAssertEqual(Set(forms).count, 3, "\(forms)")
    }
}
