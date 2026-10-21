package com.jackwallner.shop.data

import android.app.Activity
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.jackwallner.shop.BuildConfig
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * Sign in with Google, the Android counterpart of Sign in with Apple: Credential
 * Manager returns a Google id_token carrying the SHA-256 of a raw nonce, and
 * Supabase verifies both. Needs the Web OAuth client id that the Supabase
 * Google provider trusts; without one the button is hidden.
 */
object GoogleSignIn {
    val isConfigured: Boolean get() = BuildConfig.GOOGLE_WEB_CLIENT_ID.isNotBlank()

    class Cancelled : Exception()

    /** Returns (idToken, rawNonce). Throws [Cancelled] when the user backs out. */
    suspend fun requestIdToken(activity: Activity): Pair<String, String> {
        val rawNonce = randomNonce()
        val option = GetSignInWithGoogleOption.Builder(BuildConfig.GOOGLE_WEB_CLIENT_ID)
            .setNonce(sha256(rawNonce))
            .build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        val result = try {
            CredentialManager.create(activity).getCredential(activity, request)
        } catch (_: GetCredentialCancellationException) {
            throw Cancelled()
        }
        val credential = result.credential
        if (credential !is CustomCredential || credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            error("Could not read your Google credentials.")
        }
        return GoogleIdTokenCredential.createFrom(credential.data).idToken to rawNonce
    }

    fun randomNonce(length: Int = 32): String {
        val chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"
        val rng = SecureRandom()
        return String(CharArray(length) { chars[rng.nextInt(chars.length)] })
    }

    fun sha256(input: String): String =
        MessageDigest.getInstance("SHA-256").digest(input.toByteArray()).joinToString("") { "%02x".format(it) }
}
