package com.jackwallner.shop

import com.jackwallner.shop.data.KeyValueStore
import com.jackwallner.shop.data.ReviewAccess
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReviewAccessTests {
    // A throwaway fixture, not a real reviewer code.
    private val fixture = "local-review-fixture"
    private val digest = ReviewAccess.sha256(fixture)

    @Test fun digestIsLowercaseSha256Hex() {
        assertTrue(Regex("[a-f0-9]{64}").matches(digest))
        assertEquals("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", ReviewAccess.sha256(""))
    }

    @Test fun unconfiguredAccessCannotUnlock() {
        assertFalse(ReviewAccess(MapStore(), "").activate(fixture))
        assertFalse(ReviewAccess(MapStore(), "invalid").activate("invalid"))
        assertFalse(ReviewAccess(MapStore(), "").isGranted)
    }

    @Test fun wrongOrBlankCodeDoesNotGrantAccess() {
        val values = MapStore()
        val access = ReviewAccess(values, digest)
        assertFalse(access.activate("wrong"))
        assertFalse(access.activate("  "))
        assertFalse(access.isGranted)
        assertTrue(values.keys().isEmpty())
    }

    @Test fun validCodeGrantsAtOnceAndPersistsOnlyTheDigest() {
        val values = MapStore()
        val access = ReviewAccess(values, digest)
        assertTrue(access.activate(" $fixture "))
        assertTrue(access.isGranted)
        assertTrue(ReviewAccess(values, digest).isGranted)
        assertEquals(setOf("reviewAccessDigest"), values.keys())
        assertEquals(digest, values.getString("reviewAccessDigest"))
    }

    @Test fun rotatingTheDigestRevokesAnExistingGrant() {
        val values = MapStore()
        assertTrue(ReviewAccess(values, digest).activate(fixture))
        assertFalse(ReviewAccess(values, ReviewAccess.sha256("another-fixture")).isGranted)
        assertFalse(ReviewAccess(values, "").isGranted)
    }

    private class MapStore : KeyValueStore {
        val m = mutableMapOf<String, Any>()
        override fun getInt(key: String) = (m[key] as? Int) ?: 0
        override fun getLong(key: String) = (m[key] as? Long) ?: 0L
        override fun getString(key: String) = m[key] as? String
        override fun has(key: String) = key in m
        override fun putInt(key: String, value: Int) { m[key] = value }
        override fun putLong(key: String, value: Long) { m[key] = value }
        override fun putString(key: String, value: String) { m[key] = value }
        override fun keys() = m.keys.toSet()
    }
}
