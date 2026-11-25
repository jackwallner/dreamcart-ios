import Foundation

/// Copy RevenueCat can change without a release, read from the current
/// offering's metadata (a running Experiment's variant included). Every
/// variant ships in the binary; a missing or unknown value is the control,
/// which is what 1.0.5 shipped. Keys a switch reads must be set the same on
/// every offering, or an Experiment arm would flip them as a side effect.
///
/// DEBUG builds can pin any key for captures: `-dreamcart.rc.<key> <value>`.

/// The DreamCart+ trial button's wording, on the onboarding offer and the You
/// tab sheet alike (both are `PlusOfferView`, sentence case).
enum TrialCTA: String, CaseIterable, Sendable {
    static let metadataKey = "trial_cta"

    /// Control: "Start 3-day free trial", as shipped.
    case threeDay = "three_day"
    case my
    case your

    static func from(metadata: [String: Any]?) -> TrialCTA {
        RemoteConfig.value(metadataKey, in: metadata, default: .threeDay)
    }

    var title: String {
        switch self {
        case .threeDay: return String(localized: "Start \(PlusPlan.trialDays)-day free trial")
        case .my: return String(localized: "Start my free trial")
        case .your: return String(localized: "Start your free trial")
        }
    }

    /// An Apple Account that already had its trial is charged on day one, so
    /// its button promises no trial (3.1.2).
    func title(trialEligible: Bool) -> String {
        trialEligible ? title : String(localized: "Get \(PlusPlan.name)")
    }
}

/// Remote off switches. On unless the metadata says "off".
enum RemoteSwitch: String, CaseIterable, Sendable {
    /// Apple's automatic rating prompt. The app has no automatic prompt yet;
    /// whichever moment adds one checks this first.
    case ratingPrompt = "rating_prompt"
}

enum RemoteConfig {
    /// The value for `key`, or `fallback` when it is missing, not a string, or
    /// not one of the shipped variants.
    static func value<T: RawRepresentable>(_ key: String, in metadata: [String: Any]?, default fallback: T) -> T
    where T.RawValue == String {
        #if DEBUG
        if let pinned = launchOverride(key).flatMap(T.init(rawValue:)) { return pinned }
        #endif
        guard let raw = metadata?[key] as? String else { return fallback }
        return T(rawValue: raw) ?? fallback
    }

    static func isOn(_ remoteSwitch: RemoteSwitch, in metadata: [String: Any]?) -> Bool {
        #if DEBUG
        if let pinned = launchOverride(remoteSwitch.rawValue) { return pinned != "off" }
        #endif
        return (metadata?[remoteSwitch.rawValue] as? String) != "off"
    }

    #if DEBUG
    private static func launchOverride(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-dreamcart.rc.\(key)"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }
    #endif
}
