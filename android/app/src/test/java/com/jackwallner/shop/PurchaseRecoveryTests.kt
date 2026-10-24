package com.jackwallner.shop

import com.jackwallner.shop.data.PendingCoinDelivery
import com.jackwallner.shop.data.PurchaseRecovery
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PurchaseRecoveryTests {
    private fun recovery(values: MutableMap<String, String> = mutableMapOf()) =
        PurchaseRecovery(read = { values[it] }, write = { key, value -> values[key] = value })
            .apply { selectAccount("buyer") }

    @Test fun membershipWaitsForRefreshedPlusWithBoundedRetry() = runTest {
        val recovery = recovery()
        recovery.beginPlus("buyer")
        var refreshes = 0
        recovery.reconcile(pause = {}, redeem = {}, refreshPlus = { refreshes++; false }, delivered = { false })
        assertEquals(3, refreshes)
        assertTrue(recovery.pendingPlus)
        assertFalse(recovery.confirmedPlus)
        assertFalse(recovery.isRecovering)
        recovery.reconcile(pause = {}, redeem = {}, refreshPlus = { true }, delivered = { false })
        assertFalse(recovery.pendingPlus)
        assertTrue(recovery.confirmedPlus)
    }

    @Test fun profileFailureRemainsPendingAndSurfacesErrorUntilRetry() = runTest {
        val recovery = recovery()
        recovery.beginPlus("buyer")
        recovery.reconcile(pause = {}, redeem = {}, refreshPlus = { error("Offline") }, delivered = { false })
        assertTrue(recovery.pendingPlus)
        assertEquals("Offline", recovery.lastError)
        recovery.reconcile(pause = {}, redeem = {}, refreshPlus = { true }, delivered = { false })
        assertFalse(recovery.pendingPlus)
        assertNull(recovery.lastError)
    }

    @Test fun delayedCoinsSurviveRelaunchAndAccountSwitchUntilGrantConfirmed() = runTest {
        val values = mutableMapOf<String, String>()
        val recovery = recovery(values)
        val delivery = PendingCoinDelivery("pack", 1000, 42)
        recovery.beginCoins(delivery, "buyer")
        recovery.reconcile(pause = {}, redeem = {}, refreshPlus = { false }, delivered = { false })
        assertEquals(delivery, recovery.pendingCoins)
        assertNull(recovery.lastDeliveredCoins)
        val relaunched = recovery(values)
        relaunched.selectAccount("someone-else")
        assertFalse(relaunched.hasPending)
        relaunched.selectAccount("buyer")
        assertEquals(delivery, relaunched.pendingCoins)
        var grantsChecked = 0
        relaunched.reconcile(pause = {}, redeem = {}, refreshPlus = { false }, delivered = {
            assertEquals(42L, it.afterLedgerId)
            ++grantsChecked == 2
        })
        assertEquals(2, grantsChecked)
        assertNull(relaunched.pendingCoins)
        assertEquals(delivery, relaunched.lastDeliveredCoins)
        assertFalse(recovery(values).hasPending)
    }

    @Test fun reconciliationFailureIsVisibleAndDoesNotClearPaidCoins() = runTest {
        val recovery = recovery()
        recovery.beginCoins(PendingCoinDelivery("pack", 1000, 1), "buyer")
        recovery.reconcile(pause = {}, redeem = { error("Delivery unavailable") }, refreshPlus = { error("Must not refresh") }, delivered = { true })
        assertNotNull(recovery.pendingCoins)
        assertEquals("Delivery unavailable", recovery.lastError)
        assertFalse(recovery.isRecovering)
    }

    @Test fun lateStoreSuccessStaysWithPurchasingAccount() {
        val values = mutableMapOf<String, String>()
        val recovery = recovery(values)
        recovery.selectAccount("someone-else")
        recovery.beginPlus("buyer")
        recovery.beginCoins(PendingCoinDelivery("pack", 1000, 1), "buyer")
        assertFalse(recovery.hasPending)
        val relaunched = recovery(values)
        assertTrue(relaunched.pendingPlus)
        assertNotNull(relaunched.pendingCoins)
    }

    @Test fun accountSwitchDoesNotAnnounceDelivery() = runTest {
        val recovery = recovery()
        recovery.beginPlus("buyer")
        recovery.beginCoins(PendingCoinDelivery("pack", 1000, 1), "buyer")
        recovery.reconcile(pause = {}, redeem = {}, refreshPlus = {
            recovery.selectAccount("someone-else")
            true
        }, delivered = { true })
        assertFalse(recovery.confirmedPlus)
        assertNull(recovery.lastDeliveredCoins)
        recovery.selectAccount("buyer")
        assertTrue(recovery.pendingPlus)
        assertNotNull(recovery.pendingCoins)
    }
}
