package com.jackwallner.shop.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.delay
import org.json.JSONObject

data class PendingCoinDelivery(val productId: String, val coins: Int, val afterLedgerId: Long)

/** Store success stays pending until the account's benefits are confirmed. */
class PurchaseRecovery(
    private val read: (String) -> String?,
    private val write: (String, String) -> Unit,
) {
    private data class Pending(val plus: Boolean = false, val coins: PendingCoinDelivery? = null)

    var accountId by mutableStateOf<String?>(null)
        private set
    private var pending by mutableStateOf(Pending())
    var isRecovering by mutableStateOf(false)
        private set
    var lastError by mutableStateOf<String?>(null)
        private set
    var confirmedPlus by mutableStateOf(false)
        private set
    var lastDeliveredCoins by mutableStateOf<PendingCoinDelivery?>(null)
        private set
    val pendingPlus get() = pending.plus
    val pendingCoins get() = pending.coins
    val hasPending get() = pending.plus || pending.coins != null

    fun selectAccount(id: String?) {
        if (id == accountId) return
        accountId = id
        pending = load(id)
        isRecovering = false
        lastError = null
        confirmedPlus = false
        lastDeliveredCoins = null
    }

    fun beginPlus(id: String) = save(load(id).copy(plus = true), id)

    fun beginCoins(delivery: PendingCoinDelivery, id: String) = save(load(id).copy(coins = delivery), id)

    suspend fun reconcile(
        attempts: Int = 3,
        pause: suspend () -> Unit = { delay(2_000) },
        redeem: suspend () -> Unit,
        refreshPlus: suspend () -> Boolean,
        delivered: suspend (PendingCoinDelivery) -> Boolean,
    ) {
        val id = accountId ?: return
        if (isRecovering) return
        isRecovering = true
        try {
            repeat(attempts) { attempt ->
                try {
                    redeem()
                    val plus = refreshPlus()
                    if (accountId != id) return
                    confirmedPlus = plus
                    if (plus) save(pending.copy(plus = false), id)
                    val delivery = pending.coins
                    val coinsDelivered = delivery?.let { delivered(it) } ?: false
                    if (accountId != id) return
                    if (coinsDelivered) lastDeliveredCoins = delivery
                    save(pending.copy(coins = if (coinsDelivered) null else pending.coins), id)
                    lastError = null
                    if (!hasPending) return
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    if (accountId != id) return
                    lastError = e.message ?: "Couldn't confirm your purchase. Try again."
                }
                if (accountId != id || !hasPending || attempt + 1 == attempts) return
                pause()
            }
        } finally {
            if (accountId == id) isRecovering = false
        }
    }

    private fun load(id: String?): Pending {
        if (id == null) return Pending()
        val raw = read("purchaseRecovery.$id") ?: return Pending()
        return runCatching {
            val json = JSONObject(raw)
            val coins = json.optJSONObject("coins")?.let {
                PendingCoinDelivery(it.getString("productId"), it.getInt("coins"), it.getLong("afterLedgerId"))
            }
            Pending(json.optBoolean("plus"), coins)
        }.getOrDefault(Pending())
    }

    private fun save(value: Pending, id: String) {
        val json = JSONObject().put("plus", value.plus)
        value.coins?.let {
            json.put("coins", JSONObject().put("productId", it.productId).put("coins", it.coins).put("afterLedgerId", it.afterLedgerId))
        }
        write("purchaseRecovery.$id", json.toString())
        if (accountId == id) pending = value
    }
}
