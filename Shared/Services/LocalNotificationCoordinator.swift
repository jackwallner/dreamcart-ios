import Foundation
import Observation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@MainActor
protocol LocalNotificationCenter: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

@MainActor
final class SystemLocalNotificationCenter: LocalNotificationCenter {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { (continuation: CheckedContinuation<UNAuthorizationStatus, Never>) in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
@Observable
final class LocalNotificationCoordinator {
    enum AuthorizationState: Equatable {
        case notDetermined
        case denied
        case authorized
        case provisional
        case ephemeral
        case unknown

        init(_ status: UNAuthorizationStatus) {
            switch status {
            case .notDetermined: self = .notDetermined
            case .denied: self = .denied
            case .authorized: self = .authorized
            case .provisional: self = .provisional
            case .ephemeral: self = .ephemeral
            @unknown default: self = .unknown
            }
        }

        var isEnabled: Bool {
            switch self {
            case .authorized, .provisional, .ephemeral: true
            default: false
            }
        }
    }

    static let newDropsIdentifier = "dreamcart.new-drops"
    static let preferredMinuteKey = "notifications.preferredMinuteOfDay"
    static let primerShownKey = "notifications.primerShown"
    static let notificationsEnabledKey = "notifications.enabled"
    static let defaultPreferredMinuteOfDay = 9 * 60

    private let center: any LocalNotificationCenter
    private let defaults: UserDefaults
    private let calendar: Calendar

    private(set) var authorizationState: AuthorizationState = .notDetermined
    private(set) var isReconciling = false

    var preferredMinuteOfDay: Int {
        get {
            let value = defaults.object(forKey: Self.preferredMinuteKey) as? Int
            return min(max(value ?? Self.defaultPreferredMinuteOfDay, 0), 1_439)
        }
        set {
            defaults.set(min(max(newValue, 0), 1_439), forKey: Self.preferredMinuteKey)
            if isNotificationsEnabled {
                Task { await reconcile() }
            }
        }
    }

    var isPrimerShown: Bool {
        get { defaults.bool(forKey: Self.primerShownKey) }
        set { defaults.set(newValue, forKey: Self.primerShownKey) }
    }

    /// On when the shopper asked for reminders and iOS allows them. The wish
    /// is stored on its own: iOS permission going away hides it, and coming
    /// back restores it, so a trip through Settings never loses the reminder.
    var isNotificationsEnabled: Bool {
        get { wantsReminders && authorizationState.isEnabled }
        set {
            defaults.set(newValue, forKey: Self.notificationsEnabledKey)
            Task { await reconcile() }
        }
    }

    private var wantsReminders: Bool { defaults.bool(forKey: Self.notificationsEnabledKey) }

    var isDenied: Bool { authorizationState == .denied }
    var shouldPresentPrimer: Bool {
        !isPrimerShown && authorizationState == .notDetermined && !isNotificationsEnabled
    }

    var preferredTime: Date {
        get {
            calendar.date(bySettingHour: preferredMinuteOfDay / 60,
                          minute: preferredMinuteOfDay % 60,
                          second: 0, of: Date()) ?? Date()
        }
        set {
            let components = calendar.dateComponents([.hour, .minute], from: newValue)
            preferredMinuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }

    init(center: (any LocalNotificationCenter)? = nil,
         defaults: UserDefaults = .standard,
         calendar: Calendar = .current) {
        self.center = center ?? SystemLocalNotificationCenter()
        self.defaults = defaults
        self.calendar = calendar
    }

    func refreshStatus() async {
        let wasEnabled = authorizationState.isEnabled
        await readStatus()
        // Allowed again in Settings: bring back the reminder the shopper asked for.
        if !wasEnabled, authorizationState.isEnabled, wantsReminders, !isReconciling {
            await reconcile()
        }
    }

    private func readStatus() async {
        authorizationState = AuthorizationState(await center.authorizationStatus())
    }

    @discardableResult
    func requestAuthorizationAndEnable() async -> Bool {
        isPrimerShown = true
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            guard granted, authorizationState.isEnabled else {
                defaults.set(false, forKey: Self.notificationsEnabledKey)
                return false
            }
            defaults.set(true, forKey: Self.notificationsEnabledKey)
            await reconcile()
            return true
        } catch {
            await refreshStatus()
            defaults.set(false, forKey: Self.notificationsEnabledKey)
            return false
        }
    }

    func disable() async {
        defaults.set(false, forKey: Self.notificationsEnabledKey)
        cancelNewDrops()
        await readStatus()
    }

    func cancelNewDrops() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.newDropsIdentifier])
    }

    func reconcile() async {
        isReconciling = true
        defer { isReconciling = false }
        await readStatus()
        guard isNotificationsEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.newDropsIdentifier])
            return
        }

        var date = DateComponents()
        date.hour = preferredMinuteOfDay / 60
        date.minute = preferredMinuteOfDay % 60
        cancelNewDrops()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "NEW DROP")
        content.body = String(localized: "Fresh styles are waiting in DreamCart.")
        content.sound = .default
        content.userInfo = ["route": "new-drops", "url": "dreamcart://new-drops"]
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        do {
            try await center.add(UNNotificationRequest(identifier: Self.newDropsIdentifier,
                                                        content: content,
                                                        trigger: trigger))
        } catch {
            return
        }
    }

    func openSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}
