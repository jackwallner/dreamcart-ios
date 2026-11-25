import UserNotifications
import XCTest

// State machine audit repro suite, 2026-11-24. Kept out of the test target:
// copy it into DreamCartTests/ to run it. Each claim asserts the promised
// behaviour and fails on the audited commit (134b8be); each has a passing
// control beside it. Preconditions are asserted first, so a failure is the
// claim and not a broken setup.

@MainActor
final class StateMachineAuditRepro: XCTestCase {
    private final class ReproCenter: LocalNotificationCenter {
        var status: UNAuthorizationStatus = .authorized
        var pending: [String: UNNotificationRequest] = [:]

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { status == .authorized }
        func authorizationStatus() async -> UNAuthorizationStatus { status }
        func add(_ request: UNNotificationRequest) async throws { pending[request.identifier] = request }
        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            identifiers.forEach { pending[$0] = nil }
        }
    }

    private let suite = "StateMachineAuditRepro"
    private var defaults: UserDefaults!

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        try await super.tearDown()
    }

    /// A shopper with reminders on, the way Profile's toggle leaves them.
    private func remindersOn(_ center: ReproCenter) async -> LocalNotificationCoordinator {
        let coordinator = LocalNotificationCoordinator(center: center, defaults: defaults)
        await coordinator.refreshStatus()
        coordinator.isNotificationsEnabled = true
        await coordinator.reconcile()
        return coordinator
    }

    // MARK: B1. Reminders the shopper turned on never come back after iOS permission returns

    /// Profile shows "Notifications are off in Settings" and an "Allow
    /// notifications in Settings" button (ProfileView.swift:310-311,321).
    /// Following it and allowing them must bring the daily reminder back.
    /// The app's foreground path is `refreshStatus()` (DreamCartApp.swift:119).
    func testRemindersComeBackWhenPermissionIsAllowedAgain() async {
        let center = ReproCenter()
        let coordinator = await remindersOn(center)
        XCTAssertTrue(coordinator.isNotificationsEnabled, "precondition: reminders on")
        XCTAssertNotNil(center.pending[LocalNotificationCoordinator.newDropsIdentifier], "precondition: reminder scheduled")

        // iOS Settings, DreamCart, Notifications off, back to the app.
        center.status = .denied
        await coordinator.refreshStatus()
        XCTAssertTrue(coordinator.isDenied, "precondition: the app saw the permission go")

        // "Allow notifications in Settings", allow, back to the app.
        center.status = .authorized
        await coordinator.refreshStatus()
        XCTAssertFalse(coordinator.isDenied, "precondition: the app saw the permission return")

        XCTAssertTrue(coordinator.isNotificationsEnabled,
                      "the reminder toggle the shopper turned on must be on again once iOS allows it")
        XCTAssertNotNil(center.pending[LocalNotificationCoordinator.newDropsIdentifier],
                        "the daily reminder must be scheduled again once iOS allows it")
    }

    /// Control: reminders switched off in the app stay off when permission
    /// comes and goes, and nothing is scheduled while iOS says no.
    func testControlRemindersTurnedOffInTheAppStayOff() async {
        let center = ReproCenter()
        let coordinator = await remindersOn(center)
        XCTAssertNotNil(center.pending[LocalNotificationCoordinator.newDropsIdentifier], "precondition: reminder scheduled")

        await coordinator.disable()
        center.status = .denied
        await coordinator.refreshStatus()
        XCTAssertFalse(coordinator.isNotificationsEnabled)
        XCTAssertNil(center.pending[LocalNotificationCoordinator.newDropsIdentifier])

        center.status = .authorized
        await coordinator.refreshStatus()
        XCTAssertFalse(coordinator.isNotificationsEnabled)
        XCTAssertNil(center.pending[LocalNotificationCoordinator.newDropsIdentifier])
    }
}
