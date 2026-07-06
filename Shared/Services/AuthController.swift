import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

// Drives Sign in with Apple → Supabase and exposes auth state to the UI.
@MainActor
@Observable
final class AuthController {
    enum State: Equatable { case unknown, signedOut, signedIn }
    var state: State = .unknown
    var errorMessage: String?
    var isWorking = false

    private var currentNonce: String?

    func bootstrap() async {
        await SupabaseClient.shared.restore()
        let signed = await SupabaseClient.shared.isSignedIn
        state = signed ? .signedIn : .signedOut
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
            state = .signedIn
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
            state = .signedIn
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    func signOut() async {
        await SupabaseClient.shared.signOutLocal()
        state = .signedOut
    }

    func deleteAccount() async throws {
        let _: [String: Bool]? = try? await SupabaseClient.shared.callFunction("delete-account")
        await SupabaseClient.shared.signOutLocal()
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
