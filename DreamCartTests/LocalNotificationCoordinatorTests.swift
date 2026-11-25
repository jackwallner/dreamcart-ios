import UserNotifications
import XCTest

/// The daily reminder's copy is fixed when it is scheduled, so the app rebuilds
/// it on launch (a language change in Settings relaunches the app). These pin
/// that a reconcile replaces a stale pending reminder and never schedules one
/// the shopper turned off.
@MainActor
final class LocalNotificationCoordinatorTests: XCTestCase {
    private final class FakeCenter: LocalNotificationCenter {
        var status: UNAuthorizationStatus = .authorized
        var pending: [String: UNNotificationRequest] = [:]
        var addCount = 0

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
        func authorizationStatus() async -> UNAuthorizationStatus { status }
        func add(_ request: UNNotificationRequest) async throws {
            addCount += 1
            pending[request.identifier] = request
        }
        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            identifiers.forEach { pending[$0] = nil }
        }
    }

    private var defaults: UserDefaults!
    private let suite = "LocalNotificationCoordinatorTests"

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        try await super.tearDown()
    }

    private func staleRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "NEUER DROP"
        var date = DateComponents()
        date.hour = 9
        return UNNotificationRequest(identifier: LocalNotificationCoordinator.newDropsIdentifier,
                                     content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: date, repeats: true))
    }

    func testReconcileRebuildsAStaleReminderInTheCurrentLanguage() async {
        let center = FakeCenter()
        center.pending[LocalNotificationCoordinator.newDropsIdentifier] = staleRequest()
        defaults.set(true, forKey: LocalNotificationCoordinator.notificationsEnabledKey)
        let coordinator = LocalNotificationCoordinator(center: center, defaults: defaults)

        await coordinator.reconcile()

        let request = center.pending[LocalNotificationCoordinator.newDropsIdentifier]
        XCTAssertEqual(center.addCount, 1)
        XCTAssertEqual(request?.content.title, String(localized: "NEW DROP"))
        XCTAssertEqual(request?.content.body, String(localized: "Fresh styles are waiting in DreamCart."))
    }

    func testReconcileLeavesNoReminderWhenTurnedOff() async {
        let center = FakeCenter()
        center.pending[LocalNotificationCoordinator.newDropsIdentifier] = staleRequest()
        let coordinator = LocalNotificationCoordinator(center: center, defaults: defaults)

        await coordinator.reconcile()

        XCTAssertEqual(center.addCount, 0)
        XCTAssertTrue(center.pending.isEmpty)
    }

    func testReconcileLeavesNoReminderWhenPermissionWasRevoked() async {
        let center = FakeCenter()
        center.status = .denied
        center.pending[LocalNotificationCoordinator.newDropsIdentifier] = staleRequest()
        defaults.set(true, forKey: LocalNotificationCoordinator.notificationsEnabledKey)
        let coordinator = LocalNotificationCoordinator(center: center, defaults: defaults)

        await coordinator.reconcile()

        XCTAssertEqual(center.addCount, 0)
        XCTAssertTrue(center.pending.isEmpty)
        XCTAssertFalse(coordinator.isNotificationsEnabled)
    }

    // MARK: permission off and on again (state machine audit 2026-11-24, B1)

    /// The foreground path is `refreshStatus()`. Switching DreamCart's
    /// notifications off in iOS Settings used to clear the shopper's own
    /// toggle, so allowing them again brought nothing back.
    func testRemindersComeBackWhenPermissionIsAllowedAgain() async {
        let center = FakeCenter()
        let coordinator = LocalNotificationCoordinator(center: center, defaults: defaults)
        await coordinator.refreshStatus()
        coordinator.isNotificationsEnabled = true
        await coordinator.reconcile()
        XCTAssertNotNil(center.pending[LocalNotificationCoordinator.newDropsIdentifier], "precondition: scheduled")

        center.status = .denied
        await coordinator.refreshStatus()
        XCTAssertTrue(coordinator.isDenied, "precondition: denied seen")
        XCTAssertFalse(coordinator.isNotificationsEnabled, "the toggle reads off while iOS says no")

        center.status = .authorized
        await coordinator.refreshStatus()
        XCTAssertTrue(coordinator.isNotificationsEnabled)
        XCTAssertNotNil(center.pending[LocalNotificationCoordinator.newDropsIdentifier])
    }

    /// While iOS says no, a launch removes the reminder; allowing it again
    /// schedules a fresh one rather than switching the toggle off.
    func testAMissingReminderIsRestoredWhenPermissionReturnsAfterALaunch() async {
        let center = FakeCenter()
        center.status = .denied
        defaults.set(true, forKey: LocalNotificationCoordinator.notificationsEnabledKey)
        let coordinator = LocalNotificationCoordinator(center: center, defaults: defaults)
        await coordinator.reconcile()
        XCTAssertTrue(center.pending.isEmpty, "precondition: nothing scheduled while denied")

        center.status = .authorized
        await coordinator.refreshStatus()
        XCTAssertTrue(coordinator.isNotificationsEnabled)
        XCTAssertEqual(center.addCount, 1)
    }

    /// Upgrade: a shopper whose stored setting says on keeps it.
    func testAStoredOnSettingFromAnEarlierBuildStillSchedules() async {
        let center = FakeCenter()
        defaults.set(true, forKey: LocalNotificationCoordinator.notificationsEnabledKey)
        defaults.set(20 * 60, forKey: LocalNotificationCoordinator.preferredMinuteKey)
        let coordinator = LocalNotificationCoordinator(center: center, defaults: defaults)

        await coordinator.refreshStatus()

        XCTAssertTrue(coordinator.isNotificationsEnabled)
        let trigger = center.pending[LocalNotificationCoordinator.newDropsIdentifier]?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 20)
    }

    /// Reminders turned off in the app stay off when permission comes and goes.
    func testRemindersTurnedOffInTheAppStayOffAcrossPermissionChanges() async {
        let center = FakeCenter()
        let coordinator = LocalNotificationCoordinator(center: center, defaults: defaults)
        await coordinator.refreshStatus()
        coordinator.isNotificationsEnabled = true
        await coordinator.reconcile()
        await coordinator.disable()

        center.status = .denied
        await coordinator.refreshStatus()
        center.status = .authorized
        await coordinator.refreshStatus()

        XCTAssertFalse(coordinator.isNotificationsEnabled)
        XCTAssertTrue(center.pending.isEmpty)
    }
}
