import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

// Drives Sign in with Apple → Supabase and exposes auth state to the UI.
@MainActor
@Observable
final class AuthController {
    enum State: Equatable { case unknown, signedOut, guest, signedIn }
    var state: State = .unknown
    var errorMessage: String?
    var isWorking = false

    /// True while the user is browsing the catalog without an account. Only
    /// account-based features (cart, checkout, closet, coins, favorites) ask
    /// them to sign in — App Review 5.1.1(v) requires everything else to be
    /// reachable without registering.
    var isGuest: Bool { state == .guest }

    /// Raised by `requireAccount()` when a guest taps an account-based action;
    /// `RootView` presents the sign-in sheet on it.
    var promptSignIn = false

    /// Remembers a guest across launches so they land back in the catalog
    /// instead of the sign-in screen.
    private static let guestKey = "dreamcart.browsingAsGuest"

    /// Set by `WelcomeView` the moment a brand-new user finishes the
    /// onboarding slides (before they sign in). `RootView` checks this once
    /// `state` flips to `.signedIn` to decide whether to show the onboarding
    /// coin pack offer. In-memory only (not persisted), so it's naturally
    /// false again on every future launch — a returning user who already
    /// completed onboarding in a prior session never re-triggers it.
    var justCompletedOnboarding = false

    private var currentNonce: String?

    func bootstrap() async {
        await SupabaseClient.shared.restore()
        let signed = await SupabaseClient.shared.isSignedIn
        if signed {
            state = .signedIn
        } else {
            state = UserDefaults.standard.bool(forKey: Self.guestKey) ? .guest : .signedOut
        }
    }

    // MARK: guest browsing

    func continueAsGuest() {
        UserDefaults.standard.set(true, forKey: Self.guestKey)
        errorMessage = nil
        promptSignIn = false
        state = .guest
        Analytics.track("guest_browsing_started")
    }

    /// Gate for account-based actions. Returns true when the caller may
    /// proceed; for a guest it opens the sign-in sheet and returns false, so
    /// call sites read as a plain guard.
    @discardableResult
    func requireAccount(_ feature: String) -> Bool {
        guard state == .guest else { return true }
        errorMessage = nil
        promptSignIn = true
        Analytics.track("signin_prompted", ["feature": feature])
        return false
    }

    // MARK: Apple request

    func prepareRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName]
        request.nonce = Self.sha256(nonce)
    }

    func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = error.localizedDescription
        case .success(let auth):
            guard
                let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = cred.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Could not read your Apple credentials."
                return
            }
            let name = [cred.fullName?.givenName, cred.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            Task { await exchange(idToken: idToken, nonce: nonce, name: name) }
        }
    }

    private func exchange(idToken: String, nonce: String, name: String) async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await SupabaseClient.shared.signInWithApple(idToken: idToken, nonce: nonce, fullName: name)
            Haptics.success()
            finishSignIn()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    #if DEBUG
    func devSignIn() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await SupabaseClient.shared.signInWithPassword(
                email: "tester@dreamcart.dev", password: "dreamcart-test-1")
            Haptics.success()
            finishSignIn()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    /// Leaving guest mode is permanent for this install: clearing the flag
    /// means a later sign-out lands on the welcome screen, not back in a
    /// half-guest state.
    private func finishSignIn() {
        UserDefaults.standard.removeObject(forKey: Self.guestKey)
        promptSignIn = false
        errorMessage = nil
        state = .signedIn
    }

    func signOut() async {
        await SupabaseClient.shared.signOutLocal()
        UserDefaults.standard.removeObject(forKey: Self.guestKey)
        state = .signedOut
    }

    func deleteAccount() async throws {
        let _: [String: Bool] = try await SupabaseClient.shared.callFunction("delete-account")
        await SupabaseClient.shared.signOutLocal()
        UserDefaults.standard.removeObject(forKey: Self.guestKey)
        state = .signedOut
    }

    // MARK: nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < chars.count {
                result.append(chars[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
