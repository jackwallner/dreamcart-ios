import Foundation

struct PendingCoinDelivery: Codable, Equatable {
    let productId: String
    let coins: Int
    let afterLedgerId: Int
}

enum PurchaseRecoveryError: LocalizedError {
    case reconciliationFailed

    var errorDescription: String? { "Couldn't confirm your purchase. Try again." }
}

/// Store success is persisted until the account's benefits are confirmed.
@MainActor
@Observable
final class PurchaseRecovery {
    private struct Pending: Codable {
        var plus = false
        var coins: PendingCoinDelivery?
    }

    private let defaults: UserDefaults
    private(set) var accountId: String?
    private var pending = Pending()
    private(set) var isRecovering = false
    private(set) var lastError: String?
    private(set) var confirmedPlus = false
    private(set) var lastDeliveredCoins: PendingCoinDelivery?

    var pendingPlus: Bool { pending.plus }
    var pendingCoins: PendingCoinDelivery? { pending.coins }
    var hasPending: Bool { pending.plus || pending.coins != nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func selectAccount(_ id: String?) {
        guard id != accountId else { return }
        accountId = id
        pending = read(id)
        isRecovering = false
        lastError = nil
        confirmedPlus = false
        lastDeliveredCoins = nil
    }

    func beginPlus(accountId id: String) {
        var value = read(id)
        value.plus = true
        save(value, for: id)
    }

    func beginCoins(_ delivery: PendingCoinDelivery, accountId id: String) {
        var value = read(id)
        value.coins = delivery
        save(value, for: id)
    }

    func reconcile(
        attempts: Int = 3,
        pause: () async throws -> Void = { try await Task.sleep(for: .seconds(2)) },
        redeem: () async throws -> Void,
        refreshPlus: () async throws -> Bool,
        delivered: (PendingCoinDelivery) async throws -> Bool
    ) async {
        guard let id = accountId, !isRecovering else { return }
        isRecovering = true
        defer { if accountId == id { isRecovering = false } }
        for attempt in 0..<attempts {
            do {
                try Task.checkCancellation()
                try await redeem()
                let plus = try await refreshPlus()
                guard accountId == id else { return }
                confirmedPlus = plus
                if plus {
                    pending.plus = false
                    save(pending, for: id)
                }
                let delivery = pending.coins
                var coinsDelivered = false
                if let delivery = pending.coins { coinsDelivered = try await delivered(delivery) }
                guard accountId == id else { return }
                if coinsDelivered {
                    lastDeliveredCoins = delivery
                    pending.coins = nil
                }
                save(pending, for: id)
                lastError = nil
                if !hasPending { return }
            } catch is CancellationError {
                return
            } catch {
                guard accountId == id else { return }
                lastError = error.localizedDescription
            }
            guard accountId == id, hasPending, attempt + 1 < attempts else { return }
            do { try await pause() } catch { return }
        }
    }

    private func read(_ id: String?) -> Pending {
        guard let id, let data = defaults.data(forKey: "purchaseRecovery.\(id)") else { return Pending() }
        return (try? JSONDecoder().decode(Pending.self, from: data)) ?? Pending()
    }

    private func save(_ value: Pending, for id: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: "purchaseRecovery.\(id)")
        }
        if accountId == id { pending = value }
    }
}
