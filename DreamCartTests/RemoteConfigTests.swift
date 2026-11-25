import XCTest

/// The trial button wording test runs through offering metadata `trial_cta`.
/// The control must be exactly the copy that shipped, so a customer outside
/// any Experiment sees no change.
final class RemoteConfigTests: XCTestCase {
    func testMissingNonStringAndUnknownValuesAreTheControl() {
        XCTAssertEqual(TrialCTA.from(metadata: nil), .threeDay)
        XCTAssertEqual(TrialCTA.from(metadata: [:]), .threeDay)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": 1]), .threeDay)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": true]), .threeDay)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "ours"]), .threeDay)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "MY"]), .threeDay)
    }

    func testEachKnownValueReadsItsArm() {
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "three_day"]), .threeDay)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "my"]), .my)
        XCTAssertEqual(TrialCTA.from(metadata: ["trial_cta": "your"]), .your)
    }

    func testControlIsTheShippedButtonCopy() {
        // PlusOfferView's pre-change trial title, character for character.
        XCTAssertEqual(TrialCTA.threeDay.title, String(localized: "Start \(PlusPlan.trialDays)-day free trial"))
        XCTAssertEqual(TrialCTA.threeDay.title, "Start 3-day free trial")
    }

    func testEachArmsTitle() {
        XCTAssertEqual(TrialCTA.my.title, "Start my free trial")
        XCTAssertEqual(TrialCTA.your.title, "Start your free trial")
        XCTAssertEqual(Set(TrialCTA.allCases.map(\.title)).count, TrialCTA.allCases.count)
    }

    func testIneligibleAccountsAreNeverPromisedATrial() {
        for arm in TrialCTA.allCases {
            XCTAssertEqual(arm.title(trialEligible: false), String(localized: "Get \(PlusPlan.name)"))
            XCTAssertEqual(arm.title(trialEligible: false), "Get DreamCart+")
            XCTAssertEqual(arm.title(trialEligible: true), arm.title)
        }
    }

    func testSwitchIsOnUnlessTheValueIsOff() {
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: nil))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: [:]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "on"]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": false]))
        XCTAssertTrue(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "OFF"]))
        XCTAssertFalse(RemoteConfig.isOn(.ratingPrompt, in: ["rating_prompt": "off"]))
    }

    @MainActor
    func testTheStoreReadsTheControlBeforeRevenueCatAnswers() {
        let store = StoreController()
        XCTAssertNil(store.offeringMetadata)
        XCTAssertEqual(store.trialCTA, .threeDay)
        XCTAssertTrue(store.isOn(.ratingPrompt))
    }
}
