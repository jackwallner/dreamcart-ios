package com.jackwallner.shop.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import java.security.MessageDigest

/**
 * The Play reviewer unlock. The build holds only the SHA-256 of the private
 * code (`PLAY_REVIEW_CODE_SHA256`). A matching code stores that digest on this
 * install, and access holds only while the stored digest still equals the one
 * built in, so rotating the digest revokes every earlier grant. It shows
 * DreamCart+ as active on the client only: nothing is written to Supabase or
 * RevenueCat, so `profiles.is_plus` and the server-side perks are unchanged.
 */
class ReviewAccess(private val defaults: KeyValueStore, private val expectedDigest: String) {
    private val configured get() = DIGEST_PATTERN.matches(expectedDigest)

    var isGranted by mutableStateOf(configured && defaults.getString(KEY) == expectedDigest)
        private set

    fun activate(code: String): Boolean {
        if (!configured || code.isBlank()) return false
        val digest = sha256(code.trim())
        if (!MessageDigest.isEqual(digest.toByteArray(), expectedDigest.toByteArray())) return false
        defaults.putString(KEY, digest)
        isGranted = true
        return true
    }

    companion object {
        private const val KEY = "reviewAccessDigest"
        private val DIGEST_PATTERN = Regex("[a-f0-9]{64}")

        fun sha256(text: String): String =
            MessageDigest.getInstance("SHA-256").digest(text.toByteArray()).joinToString("") { "%02x".format(it) }
    }
}
