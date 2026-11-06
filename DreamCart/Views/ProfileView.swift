import SwiftUI

struct ProfileView: View {
    /// The language the app is running in, named in that language, as iOS
    /// Settings names it ("Deutsch", "Español").
    private static var currentLanguageName: String {
        guard let code = Bundle.main.preferredLocalizations.first else { return "" }
        let locale = Locale(identifier: code)
        guard let name = locale.localizedString(forLanguageCode: code) else { return code }
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    @Environment(AuthController.self) private var auth
    @Environment(ShopStore.self) private var shop
    @Environment(LocalNotificationCoordinator.self) private var notifications
    @Environment(ShippingAddressStore.self) private var shipping
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @State private var showCoinShop = false
    @State private var showPlusOffer = false
    @State private var showNotificationPrimer = false
    @State private var showLedger = false
    @State private var showShipping = false
    @State private var confirmDelete = false
    @State private var working = false
    @State private var deleteError: String?
    @State private var profileError: String?
    @State private var ledgerLoading = false
    @AppStorage("appearance") private var appearance = Appearance.light.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if auth.isGuest {
                        guestHeader
                        appearanceCard
                        notificationCard
                        guestActions
                    } else {
                        header
                        PurchaseRecoveryStatus()
                        statsGrid
                        appearanceCard
                        notificationCard
                        if !isScreenshotMode {
                            actions
                        }
                        dangerZone
                    }
                    Text("DreamCart is a virtual shopping game. Everything here, including coins, items, and delivery, is imaginary and has no cash value.")
                        .font(.dcCaption)
                        .foregroundStyle(Theme.subtle(scheme))
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding(16)
            }
            .reservesFloatingTabBar()
            .background(Theme.bg(scheme))
            .navigationTitle("You")
            .walletToolbar($showCoinShop)
            .sheet(isPresented: $showPlusOffer) {
                PlusOfferView(presentation: .sheet) { showPlusOffer = false }
            }
            .sheet(isPresented: $showLedger) { LedgerView() }
            .sheet(isPresented: $showNotificationPrimer) { NotificationPrimerView() }
            .task { await notifications.refreshStatus() }
            .disabled(working)
        }
        // Outside the stack, so unfolded it covers the whole You pane.
        .paneSheet(isPresented: $showShipping) { ShippingAddressView() }
        .overlay {
            if working {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().controlSize(.large)
                        Text("Deleting your account…").font(.dcBody)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCorner))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Deleting your account")
            }
        }
        .alert("Action not completed", isPresented: Binding(
            get: { profileError != nil },
            set: { if !$0 { profileError = nil } }
        )) {
            Button("OK") { profileError = nil }
        } message: {
            Text(profileError ?? "")
        }
        .alert("Account not deleted", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("Try again") { deleteAccount() }
            Button("Cancel", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.candy).frame(width: 84, height: 84)
                Text(String(displayName.prefix(1)).uppercased())
                    .font(.dcHero)
                    .foregroundStyle(.white)
            }
            Text(displayName)
                .font(.dcTitle)
                .foregroundStyle(Theme.ink(scheme))
            HStack(spacing: 5) {
                Image(systemName: "flame.fill").foregroundStyle(Theme.coral)
                Text("\(shop.me?.liveStreak() ?? 0)-day streak")
                    .font(.dcLabel)
                    .foregroundStyle(Theme.subtle(scheme))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardStyle(scheme)
    }

    // MARK: guest

    private var guestHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.candy).frame(width: 84, height: 84)
                Image(systemName: "person.fill")
                    .font(.dcIconL)
                    .foregroundStyle(.white)
            }
            Text("Browsing as guest")
                .font(.dcTitle)
                .foregroundStyle(Theme.ink(scheme))
            Text("Sign in to earn coins and keep a closet.")
                .font(.dcLabel)
                .foregroundStyle(Theme.subtle(scheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .cardStyle(scheme)
    }

    private var guestActions: some View {
        VStack(spacing: 0) {
            row(String(localized: "Sign in"), "person.crop.circle.badge.plus", Theme.violet) {
                auth.requireAccount("profile")
            }
            Divider().padding(.leading, 50)
            linkRow(String(localized: "Privacy Policy"), "hand.raised.fill",
                    URL(string: "https://jackwallner.github.io/dreamcart/privacy-policy.html")!)
            Divider().padding(.leading, 50)
            linkRow(String(localized: "Terms of Use"), "doc.text.fill",
                    URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
        }
        .cardStyle(scheme)
    }

    private func linkRow(_ title: String, _ icon: String, _ url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.dcIconM)
                    .foregroundStyle(Theme.subtle(scheme)).frame(width: 24)
                Text(title).font(.dcBody)
                    .foregroundStyle(Theme.ink(scheme))
                Spacer()
                Image(systemName: "arrow.up.right").font(.dcIconS)
                    .foregroundStyle(Theme.subtle(scheme).opacity(0.5))
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var displayName: String {
        let name = shop.me?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? String(localized: "Shopper") : name
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statTile(DisplayFormat.coins(shop.coins), PluralLabel.coins(shop.coins), "circle.fill", Theme.gold)
            statTile((shop.me?.itemsOwned ?? 0).formatted(), String(localized: "Owned"), "bag.fill", Theme.violet)
            statTile((shop.me?.bestStreak ?? 0).formatted(), String(localized: "Best"), "flame.fill", Theme.pink)
        }
    }

    private func statTile(_ v: String, _ l: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.dcIconM).foregroundStyle(tint)
            Text(v).font(.dcStat)
                .foregroundStyle(Theme.ink(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(l).font(.dcCaption)
                .foregroundStyle(Theme.subtle(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16).cardStyle(scheme)
    }

    private var appearanceCard: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    appearanceLabel
                    Spacer()
                    appearancePicker.frame(width: 180)
                }
                VStack(alignment: .leading, spacing: 12) {
                    appearanceLabel
                    appearancePicker
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Divider().padding(.leading, 14)
            languageRow
        }
        .cardStyle(scheme)
    }

    // iOS keeps the per-app language on the app's own Settings page, where
    // few people think to look. This row only points there.
    private var languageRow: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 14) {
                Label("Language", systemImage: "globe")
                    .font(.dcBody)
                    .foregroundStyle(Theme.ink(scheme))
                Spacer()
                Text(Self.currentLanguageName)
                    .font(.dcBody)
                    .foregroundStyle(Theme.subtle(scheme))
                Image(systemName: "arrow.up.right").font(.dcIconS)
                    .foregroundStyle(Theme.subtle(scheme).opacity(0.5))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens iOS Settings")
    }

    private var appearanceLabel: some View {
        Label("Appearance", systemImage: "sun.max.fill")
            .font(.dcBody)
            .foregroundStyle(Theme.ink(scheme))
    }

    private var appearancePicker: some View {
        Picker("Appearance", selection: $appearance) {
            ForEach(Appearance.allCases) { option in
                Text(option.label).tag(option.rawValue)
            }
        }
        .pickerStyle(.segmented)
    }

    private var notificationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "bell.badge.fill").font(.dcIconM)
                    .foregroundStyle(Theme.violet).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("New drop reminders").font(.dcBody)
                        .foregroundStyle(Theme.ink(scheme))
                    Text(notificationStatusText)
                        .font(.dcCaption)
                        .foregroundStyle(Theme.subtle(scheme))
                }
                Spacer()
                Toggle("New drop reminders", isOn: Binding(
                    get: { notifications.isNotificationsEnabled },
                    set: { enabled in
                        if enabled {
                            if notifications.authorizationState == .notDetermined {
                                showNotificationPrimer = true
                            } else if notifications.authorizationState.isEnabled {
                                notifications.isNotificationsEnabled = true
                            } else {
                                notifications.openSettings()
                            }
                        } else {
                            Task { await notifications.disable() }
                        }
                    }))
                    .labelsHidden()
            }
            DatePicker("Reminder time", selection: Binding(
                get: { notifications.preferredTime },
                set: { notifications.preferredTime = $0 }), displayedComponents: .hourAndMinute)
                .font(.dcSub)
                .disabled(!notifications.isNotificationsEnabled)
            if notifications.isDenied {
                Button("Allow notifications in Settings") { notifications.openSettings() }
                    .font(.dcLabel)
                    .foregroundStyle(Theme.violet)
            }
        }
        .padding(14)
        .cardStyle(scheme)
    }

    private var notificationStatusText: String {
        if notifications.isDenied { return String(localized: "Notifications are off in Settings") }
        if notifications.isNotificationsEnabled { return String(localized: "One reminder daily at \(Self.timeString(notifications.preferredTime))") }
        return String(localized: "Off")
    }

    private static func timeString(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private var actions: some View {
        VStack(spacing: 0) {
            if !isScreenshotMode {
                plusRow
            }
            Divider().padding(.leading, 50)
            row(String(localized: "Get more coins"), "plus.circle.fill", Theme.violet) { showCoinShop = true }
                .accessibilityIdentifier("profile.get-coins")
            Divider().padding(.leading, 50)
            subtitledRow(String(localized: "Shipping address"), shippingSubtitle, "shippingbox.fill", Theme.coral) { showShipping = true }
            Divider().padding(.leading, 50)
            row(ledgerLoading ? String(localized: "Loading coin history…") : String(localized: "Coin history"),
                "clock.arrow.circlepath", Theme.subtle(scheme)) {
                guard !ledgerLoading else { return }
                Task {
                    ledgerLoading = true
                    defer { ledgerLoading = false }
                    do {
                        try await shop.loadLedger()
                        showLedger = true
                    } catch {
                        profileError = error.localizedDescription
                    }
                }
            }
            Divider().padding(.leading, 50)
            row(String(localized: "Sign out"), "rectangle.portrait.and.arrow.right", Theme.subtle(scheme)) {
                Task {
                    await auth.signOut()
                    if auth.state != .signedOut {
                        profileError = auth.errorMessage ?? String(localized: "Could not sign out. Try again.")
                    }
                }
            }
        }
        .cardStyle(scheme)
    }

    private var isScreenshotMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-DreamCartScreenshot")
        #else
        return false
        #endif
    }

    /// The only entry point to DreamCart+ outside onboarding, which runs once
    /// and never again. Without it nobody already using the app could subscribe,
    /// and a reinstalled member had nowhere to restore from (App Review 3.1.1).
    /// Members get Apple's own management screen instead (3.1.2).
    @ViewBuilder
    private var plusRow: some View {
        if shop.me?.isPlus == true {
            subtitledRow(PlusPlan.name, String(localized: "Active · manage or cancel in the App Store"),
                         "crown.fill", Theme.gold) {
                openURL(PlusLinks.manage)
            }
        } else {
            subtitledRow(PlusPlan.name, String(localized: "Double daily coins, unlimited spins"),
                         "crown.fill", Theme.gold) {
                showPlusOffer = true
            }
        }
    }

    private func row(_ title: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.dcIconM).foregroundStyle(tint).frame(width: 24)
                Text(title).font(.dcBody)
                    .foregroundStyle(Theme.ink(scheme))
                Spacer()
                Image(systemName: "chevron.forward").font(.dcIconS).foregroundStyle(Theme.subtle(scheme).opacity(0.5))
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func subtitledRow(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color,
                              action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.dcIconM).foregroundStyle(tint).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.dcBody)
                        .foregroundStyle(Theme.ink(scheme))
                    Text(subtitle).font(.dcCaption)
                        .foregroundStyle(Theme.subtle(scheme))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.forward").font(.dcIconS).foregroundStyle(Theme.subtle(scheme).opacity(0.5))
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var shippingSubtitle: String {
        let address = shipping.address
        if !address.isValid { return String(localized: "Add an address for checkout") }
        return [address.city, address.state].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: ", ")
    }

    private var dangerZone: some View {
        Button {
            confirmDelete = true
        } label: {
            Text("Delete account")
                .font(.dcBody)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .cardStyle(scheme)
        .confirmationDialog("Delete your account? This erases your closet, coins, and streak for good.",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func deleteAccount() {
        guard !working else { return }
        Task {
            working = true
            defer { working = false }
            do {
                try await auth.deleteAccount()
                deleteError = nil
            } catch {
                Haptics.warning()
                deleteError = error.localizedDescription
            }
        }
    }
}

struct LedgerView: View {
    @Environment(ShopStore.self) private var shop
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            Group {
                if shop.ledger.isEmpty {
                    EmptyState(icon: "clock.arrow.circlepath", title: String(localized: "No coin activity yet"),
                               message: String(localized: "Daily drops, spins, shopping, and coin packs will appear here."))
                } else {
                    List {
                        ForEach(shop.ledger) { e in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(label(e.reason))
                                        .font(.dcBody)
                                    Text(e.createdAt.prefix(10))
                                        .font(.dcSub)
                                        .foregroundStyle(Theme.subtle(scheme))
                                }
                                Spacer()
                                Text(DisplayFormat.signedCoins(e.delta))
                                    .font(.dcPrice)
                                    .foregroundStyle(e.delta > 0 ? .green : Theme.pink)
                                    .monospacedDigit()
                            }
                            .listRowBackground(Theme.surface(scheme))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.bg(scheme))
            .navigationTitle("Coin history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func label(_ reason: String) -> String {
        switch reason {
        case "welcome": return String(localized: "Welcome bonus")
        case "daily": return String(localized: "Daily drop")
        case "spin": return String(localized: "Spin the wheel")
        case "checkout": return String(localized: "Shopping")
        case "pack": return String(localized: "Coin pack")
        default: return reason.capitalized
        }
    }
}
