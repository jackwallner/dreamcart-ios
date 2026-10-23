package com.jackwallner.shop.data

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.shop.BuildConfig
import com.jackwallner.shop.model.CoinPack
import com.jackwallner.shop.model.PlusPlan
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesErrorCode
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitGetProducts
import com.revenuecat.purchases.awaitLogIn
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import com.revenuecat.purchases.models.StoreProduct
import com.revenuecat.purchases.models.SubscriptionOption
import com.revenuecat.purchases.paywalls.events.CustomPaywallImpressionParams
import kotlin.coroutines.cancellation.CancellationException

enum class PurchaseOutcome { PURCHASED, PENDING, CANCELLED, FAILED }

/**
 * `StoreController.swift`: RevenueCat coin packs and the DreamCart+ weekly
 * membership. Coins and `is_plus` are granted server-side (redeem function and
 * webhook), so this runs the purchase and the caller reconciles with Supabase.
 * Debug builds use the Test Store key; release builds the Play key. Products
 * are fetched by id, so no offering is needed for a purchase to work.
 */
class StoreService(private val context: Context, private val diagnostics: ConversionDiagnostics) {
    val prices = mutableStateMapOf<String, String>()
    var isPurchasing by mutableStateOf(false)
        private set
    var lastError by mutableStateOf<String?>(null)
    var plusTrialEligible by mutableStateOf(false)
        private set

    /** Debug-only: the Plus button buys the Test Store offering's first package (`-rcfunnelprobe`). */
    var testStoreProbe = false
    /** Screenshot runs record no paywall impressions. */
    var suppressImpressions = false

    private var products: Map<String, StoreProduct> = emptyMap()
    private var configured = false
    private val impressionsThisSession = mutableSetOf<String>()

    val isConfigured: Boolean get() = configured
    val plusPrice: String? get() = prices[PlusPlan.PRODUCT_ID]
    fun price(pack: CoinPack): String = prices[pack.productId] ?: pack.fallbackPrice

    private fun configureIfNeeded(): Boolean {
        if (configured) return true
        val key = BuildConfig.REVENUECAT_API_KEY
        if (key.isBlank()) return false
        // The production goog_ key never runs in a debuggable build, and the Test
        // Store key never ships in a release build.
        if (BuildConfig.DEBUG && !key.startsWith("test_")) return false
        if (!BuildConfig.DEBUG && !key.startsWith("goog_")) return false
        Purchases.logLevel = if (BuildConfig.DEBUG) LogLevel.DEBUG else LogLevel.ERROR
        val builder = PurchasesConfiguration.Builder(context, key)
        // Test Store runs share one tester instead of a fresh anonymous customer
        // per install, so test installs don't inflate the live project's New and
        // Active Customers. Never with the Play key: real buyers would share one identity.
        if (key.startsWith("test_")) builder.appUserID("qa-android")
        Purchases.configure(builder.build())
        configured = true
        return true
    }

    /** Attach purchases to the Supabase user id so the webhook and redeem find the right profile. */
    suspend fun configure(userId: String?) {
        if (!configureIfNeeded()) return
        if (userId != null && Purchases.sharedInstance.appUserID != userId) {
            runCatching { Purchases.sharedInstance.awaitLogIn(userId) }
        }
        loadProducts()
    }

    suspend fun loadProducts() {
        if (!configureIfNeeded()) return
        try {
            val ids = CoinPack.all.map { it.productId } + PlusPlan.PRODUCT_ID
            val found = Purchases.sharedInstance.awaitGetProducts(ids)
            products = found.associateBy { it.id.substringBefore(':') }
            for ((id, product) in products) prices[id] = product.price.formatted
            val plus = products[PlusPlan.PRODUCT_ID]
            plusTrialEligible = plus?.let(::freeTrialOption) != null
            plus?.let { p -> weeklyOption(p)?.let { prices[PlusPlan.PRODUCT_ID] = it.fullPricePhase?.price?.formatted ?: p.price.formatted } }
        } catch (e: CancellationException) {
            throw e
        } catch (_: Throwable) {
            // Prices fall back to the catalog copy; purchase retries the load.
        }
    }

    /** Play only lists offers this account can still take, so a free phase means eligible. */
    private fun freeTrialOption(p: StoreProduct): SubscriptionOption? =
        p.subscriptionOptions?.firstOrNull { it.freePhase != null }

    private fun weeklyOption(p: StoreProduct): SubscriptionOption? =
        p.subscriptionOptions?.firstOrNull { it.isBasePlan } ?: p.defaultOption

    fun trackPaywallImpression(id: String, oncePerSession: Boolean = false) {
        if (suppressImpressions) return
        if (oncePerSession && !impressionsThisSession.add(id)) return
        diagnostics.recordPitchView(id)
        if (!configureIfNeeded()) return
        syncConversionAttributes()
        runCatching { Purchases.sharedInstance.trackCustomPaywallImpression(CustomPaywallImpressionParams(id)) }
    }

    private fun syncConversionAttributes() {
        if (!configured) return
        val attributes = diagnostics.subscriberAttributes
        if (attributes.isNotEmpty()) runCatching { Purchases.sharedInstance.setAttributes(attributes) }
    }

    suspend fun purchase(activity: Activity, pack: CoinPack): PurchaseOutcome {
        val product = product(pack.productId) ?: run {
            lastError = "This pack isn't available right now."
            return PurchaseOutcome.FAILED
        }
        return run(activity, product, plan = pack.productId, startedTrial = false)
    }

    suspend fun purchasePlus(activity: Activity): PurchaseOutcome {
        if (testStoreProbe && BuildConfig.DEBUG) return runProbePurchase(activity)
        val product = product(PlusPlan.PRODUCT_ID) ?: run {
            lastError = "${PlusPlan.NAME} isn't available right now."
            return PurchaseOutcome.FAILED
        }
        // Read eligibility before buying: the purchase consumes the trial.
        val withTrial = plusTrialEligible
        val option = (if (withTrial) freeTrialOption(product) else null) ?: weeklyOption(product)
        return run(activity, product, PlusPlan.CONVERSION_PLAN, withTrial, option)
    }

    /** Subscriptions need a restore path; coin packs are consumables held by the account. */
    suspend fun restorePlus(): Boolean {
        if (!configureIfNeeded()) {
            lastError = "Purchases aren't available in this build."
            return false
        }
        return try {
            val info = Purchases.sharedInstance.awaitRestore()
            info.activeSubscriptions.any { it.substringBefore(':') == PlusPlan.PRODUCT_ID }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            lastError = e.message
            false
        }
    }

    private suspend fun product(id: String): StoreProduct? {
        products[id]?.let { return it }
        loadProducts()
        return products[id]
    }

    /**
     * The Test Store mirrors carry generic ids (monthly, yearly, lifetime), so the
     * probe buys the current offering's first package through the same [run] path.
     * Those ids are not in the webhook's Plus list, so nothing server-side changes.
     */
    private suspend fun runProbePurchase(activity: Activity): PurchaseOutcome {
        if (!configureIfNeeded()) return PurchaseOutcome.FAILED
        val pkg = runCatching { Purchases.sharedInstance.awaitOfferings().current?.availablePackages?.firstOrNull() }.getOrNull()
            ?: run {
                lastError = "${PlusPlan.NAME} isn't available right now."
                return PurchaseOutcome.FAILED
            }
        return run(activity, pkg.product, PlusPlan.CONVERSION_PLAN, false)
    }

    private suspend fun run(
        activity: Activity,
        product: StoreProduct,
        plan: String,
        startedTrial: Boolean,
        option: SubscriptionOption? = null,
    ): PurchaseOutcome {
        if (!configureIfNeeded()) {
            lastError = "Purchases aren't available in this build."
            return PurchaseOutcome.FAILED
        }
        isPurchasing = true
        lastError = null
        return try {
            val params = if (option != null) PurchaseParams.Builder(activity, option) else PurchaseParams.Builder(activity, product)
            val result = Purchases.sharedInstance.awaitPurchase(params.build())
            // Pending Play purchases arrive later; nothing is granted until Play reports PURCHASED.
            if (result.storeTransaction.purchaseState == com.revenuecat.purchases.models.PurchaseState.PENDING) {
                return PurchaseOutcome.PENDING
            }
            diagnostics.recordConversion(plan, startedTrial)
            syncConversionAttributes()
            PurchaseOutcome.PURCHASED
        } catch (e: PurchasesTransactionException) {
            if (e.userCancelled || e.error.code == PurchasesErrorCode.PurchaseCancelledError) return PurchaseOutcome.CANCELLED
            if (e.error.code == PurchasesErrorCode.PaymentPendingError) return PurchaseOutcome.PENDING
            lastError = e.error.message
            PurchaseOutcome.FAILED
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            lastError = e.message ?: "Purchase didn't complete. You weren't charged."
            PurchaseOutcome.FAILED
        } finally {
            isPurchasing = false
        }
    }
}
