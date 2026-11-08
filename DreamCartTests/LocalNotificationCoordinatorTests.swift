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
}
