import SwiftUI

struct ProfileView: View {
    @Environment(AuthController.self) private var auth
    @Environment(ShopStore.self) private var shop
    @Environment(\.colorScheme) private var scheme
    @State private var showCoinShop = false
    @State private var showLedger = false
    @State private var confirmDelete = false
    @State private var working = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    statsGrid
                    actions
                    dangerZone
                    Text("DreamCart is a virtual shopping game. Everything here, including coins, items, and delivery, is imaginary and has no cash value.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.subtle(scheme))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(16)
            }
            .background(Theme.bg(scheme))
            .navigationTitle("You")
            .walletToolbar($showCoinShop)
            .sheet(isPresented: $showLedger) { LedgerView() }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.candy).frame(width: 84, height: 84)
                Text(String((shop.me?.displayName ?? "S").prefix(1)).uppercased())
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(shop.me?.displayName ?? "Shopper")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink(scheme))
            HStack(spacing: 5) {
                Image(systemName: "flame.fill").foregroundStyle(Theme.coral)
                Text("\(shop.me?.streak ?? 0)-day streak")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.subtle(scheme))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardStyle(scheme)
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statTile(Format.coins(shop.coins), "Coins", "circle.fill", Theme.gold)
            statTile("\(shop.me?.itemsOwned ?? 0)", "Owned", "bag.fill", Theme.violet)
            statTile("\(shop.me?.bestStreak ?? 0)", "Best", "flame.fill", Theme.pink)
        }
    }

    private func statTile(_ v: String, _ l: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(tint)
            Text(v).font(.system(size: 19, weight: .black, design: .rounded)).foregroundStyle(Theme.ink(scheme))
            Text(l).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(Theme.subtle(scheme))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16).cardStyle(scheme)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            row("Get more coins", "plus.circle.fill", Theme.violet) { showCoinShop = true }
            Divider().padding(.leading, 50)
            row("Coin history", "clock.arrow.circlepath", Theme.subtle(scheme)) {
                Task { await shop.loadLedger() }; showLedger = true
            }
            Divider().padding(.leading, 50)
            row("Sign out", "rectangle.portrait.and.arrow.right", Theme.subtle(scheme)) {
                Task { await auth.signOut() }
            }
        }
        .cardStyle(scheme)
    }

    private func row(_ title: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 17)).foregroundStyle(tint).frame(width: 24)
                Text(title).font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.ink(scheme))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.subtle(scheme).opacity(0.5))
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var dangerZone: some View {
        Button {
            confirmDelete = true
        } label: {
            Text("Delete account")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .cardStyle(scheme)
        .confirmationDialog("Delete your account? This erases your closet, coins, and streak for good.",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                Task { working = true; try? await auth.deleteAccount(); working = false }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct LedgerView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            List {
                ForEach(shop.ledger) { e in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(label(e.reason))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text(e.createdAt.prefix(10))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.subtle(scheme))
                        }
                        Spacer()
                        Text("\(e.delta > 0 ? "+" : "")\(Format.coins(e.delta))")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(e.delta > 0 ? .green : Theme.pink)
                            .monospacedDigit()
                    }
                    .listRowBackground(Theme.surface(scheme))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg(scheme))
            .navigationTitle("Coin history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func label(_ reason: String) -> String {
        switch reason {
        case "welcome": return "Welcome bonus"
        case "daily": return "Daily drop"
        case "spin": return "Spin the wheel"
        case "checkout": return "Shopping"
        case "pack": return "Coin pack"
        default: return reason.capitalized
        }
    }
}
