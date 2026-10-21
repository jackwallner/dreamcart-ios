package com.jackwallner.shop.data

import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.shop.model.Brand
import com.jackwallner.shop.model.CatalogLogic
import com.jackwallner.shop.model.DailyResult
import com.jackwallner.shop.model.LedgerEntry
import com.jackwallner.shop.model.MeSnapshot
import com.jackwallner.shop.model.Product
import com.jackwallner.shop.model.PurchaseResult
import com.jackwallner.shop.model.ShippingAddress
import com.jackwallner.shop.model.SpinResult
import com.jackwallner.shop.model.objects
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

enum class AuthState { UNKNOWN, SIGNED_OUT, GUEST, SIGNED_IN }

/**
 * `AuthController.swift` + `ShopStore.swift`: auth state, the catalog, and the
 * signed-in user's economy. Every coin mutation round-trips through a server
 * RPC, so the app only ever shows the authoritative balance.
 */
class ShopStore(
    private val sb: SupabaseClient,
    private val prefs: SharedPreferences,
    private val analytics: Analytics,
    private val scope: CoroutineScope,
) {
    // Auth
    var authState by mutableStateOf(AuthState.UNKNOWN)
        private set
    var authError by mutableStateOf<String?>(null)
    var authWorking by mutableStateOf(false)
        private set
    /** Raised when a guest taps an account feature; the root shows the sign-in sheet. */
    var promptSignIn by mutableStateOf(false)
    /** Set when onboarding finishes in this process; shows the Plus offer once after sign-in. */
    var justCompletedOnboarding by mutableStateOf(false)
    var hasCompletedOnboarding by mutableStateOf(prefs.getBoolean("hasCompletedOnboarding", false))
        private set

    val isGuest: Boolean get() = authState == AuthState.GUEST

    // Economy and catalog
    var me by mutableStateOf<MeSnapshot?>(null)
        private set
    var brands by mutableStateOf<List<Brand>>(emptyList())
        private set
    var products by mutableStateOf<List<Product>>(emptyList())
        private set
    var closet by mutableStateOf<List<Product>>(emptyList())
        private set
    var closetAcquiredAt by mutableStateOf<Map<String, String>>(emptyMap())
        private set
    var favoriteIds by mutableStateOf<Set<String>>(emptySet())
        private set
    var dismissedIds by mutableStateOf<Set<String>>(emptySet())
        private set
    var acceptedIds by mutableStateOf<Set<String>>(emptySet())
        private set
    val cartIds = mutableStateListOf<String>()
    var ledger by mutableStateOf<List<LedgerEntry>>(emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var hasLoadedOnce by mutableStateOf(false)
        private set
    var loadError by mutableStateOf<String?>(null)
        private set
    var isLoadingMoreProducts by mutableStateOf(false)
        private set
    private var catalogGeneration = 0
    var shipping by mutableStateOf(loadAddress())
        private set

    val coins: Int get() = me?.coins ?: 0
    val ownedIds: Set<String> get() = closet.map { it.id }.toSet()

    fun logic() = CatalogLogic(products, ownedIds, favoriteIds, dismissedIds, acceptedIds, cartIds.toList())

    // MARK: auth

    fun bootstrap() {
        authState = when {
            sb.isSignedIn -> AuthState.SIGNED_IN
            prefs.getBoolean(GUEST_KEY, false) -> AuthState.GUEST
            else -> AuthState.SIGNED_OUT
        }
        onAuthChanged()
    }

    fun completeOnboarding() {
        analytics.track("onboarding_completed")
        justCompletedOnboarding = true
        hasCompletedOnboarding = true
        prefs.edit().putBoolean("hasCompletedOnboarding", true).apply()
    }

    fun continueAsGuest() {
        prefs.edit().putBoolean(GUEST_KEY, true).apply()
        authError = null
        promptSignIn = false
        authState = AuthState.GUEST
        analytics.track("guest_browsing_started")
        onAuthChanged()
    }

    /** Gate for account features: true when the caller may proceed, else opens sign-in. */
    fun requireAccount(feature: String): Boolean {
        if (authState != AuthState.GUEST) return true
        authError = null
        promptSignIn = true
        analytics.track("signin_prompted", mapOf("feature" to feature))
        return false
    }

    suspend fun signIn(block: suspend () -> Unit) {
        authWorking = true
        try {
            block()
            prefs.edit().remove(GUEST_KEY).apply()
            promptSignIn = false
            authError = null
            authState = AuthState.SIGNED_IN
            onAuthChanged()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            authError = e.message ?: "Sign-in failed. Try again."
        } finally {
            authWorking = false
        }
    }

    suspend fun signInWithGoogle(idToken: String, rawNonce: String) = signIn { sb.signInWithIdToken("google", idToken, rawNonce) }

    /** Debug tester account, the same one the iOS DEBUG button uses. */
    suspend fun devSignIn() = signIn { sb.signInWithPassword("tester@dreamcart.dev", "dreamcart-test-1") }

    fun signOut() {
        sb.signOutLocal()
        prefs.edit().remove(GUEST_KEY).apply()
        clearAccountState()
        authState = AuthState.SIGNED_OUT
    }

    suspend fun deleteAccount() {
        sb.callFunction("delete-account")
        signOut()
    }

    private fun clearAccountState() {
        me = null
        closet = emptyList()
        closetAcquiredAt = emptyMap()
        favoriteIds = emptySet()
        ledger = emptyList()
        cartIds.clear()
    }

    /** Hook for the store to attach RevenueCat to the user; set by AppGraph. */
    var onSignedIn: suspend (String?) -> Unit = {}

    private fun onAuthChanged() {
        when (authState) {
            AuthState.SIGNED_IN -> scope.launch {
                onSignedIn(sb.currentUserId)
                refreshAll()
                reconcilePurchases()
            }
            AuthState.GUEST -> scope.launch { refreshCatalogForGuest() }
            else -> Unit
        }
    }

    // MARK: loading

    suspend fun refreshAll() {
        android.util.Log.i("DreamCart", "refreshAll start")
        isLoading = true
        loadError = null
        try {
            coroutineScope {
                val m = async { MeSnapshot.from(JSONObject(sb.rpc("me"))) }
                val b = async { JSONArray(sb.select(BRANDS)).objects().map(Brand::from) }
                val p = async { JSONArray(sb.select(PRODUCTS)).objects().map(Product::from) }
                me = m.await()
                brands = b.await()
                products = p.await()
            }
            loadRemainingCatalog(authed = true)
            loadCloset()
            loadFavorites()
            loadRecommendationFeedback()
            android.util.Log.i("DreamCart", "refreshAll done: ${products.size} products, ${closet.size} owned")
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            android.util.Log.w("DreamCart", "refreshAll failed", e)
            loadError = e.message ?: "Couldn't load DreamCart."
            if (e is SupabaseError.NotAuthenticated) signOut()
        } finally {
            isLoading = false
            hasLoadedOnce = true
        }
    }

    /** Brands and products are world-readable, so a guest loads them on the anon key. */
    suspend fun refreshCatalogForGuest() {
        isLoading = true
        loadError = null
        clearAccountState()
        try {
            coroutineScope {
                val b = async { JSONArray(sb.select(BRANDS, authed = false)).objects().map(Brand::from) }
                val p = async { JSONArray(sb.select(PRODUCTS, authed = false)).objects().map(Product::from) }
                brands = b.await()
                products = p.await()
            }
            loadRemainingCatalog(authed = false)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Throwable) {
            android.util.Log.w("DreamCart", "guest catalog failed", e)
            loadError = e.message ?: "Couldn't load the catalog."
        } finally {
            isLoading = false
            hasLoadedOnce = true
        }
    }

    /**
     * Drains the rest of the catalog in 1000-row pages, buffered and appended
     * once, so the grids re-render a single time (`loadRemainingCatalog`).
     */
    private fun loadRemainingCatalog(authed: Boolean) {
        val generation = ++catalogGeneration
        scope.launch {
            isLoadingMoreProducts = true
            val collected = mutableListOf<Product>()
            var offset = products.size
            try {
                while (generation == catalogGeneration) {
                    val page = JSONArray(sb.select("$PRODUCT_QUERY&offset=$offset&limit=$PAGE_SIZE", authed)).objects().map(Product::from)
                    collected += page
                    if (page.size < PAGE_SIZE) break
                    offset += PAGE_SIZE
                }
            } catch (e: CancellationException) {
                throw e
            } catch (_: Throwable) {
                // Keep whatever arrived; the first page is already on screen.
            } finally {
                if (generation == catalogGeneration) {
                    if (collected.isNotEmpty()) products = CatalogLogic.appendPage(products, collected)
                    isLoadingMoreProducts = false
                }
            }
        }
    }

    suspend fun refresh() = if (authState == AuthState.SIGNED_IN) refreshAll() else refreshCatalogForGuest()

    suspend fun refreshMe() {
        runCatching { me = MeSnapshot.from(JSONObject(sb.rpc("me"))) }
    }

    suspend fun loadCloset() {
        runCatching {
            val rows = JSONArray(sb.select("closet_items?select=acquired_at,products(*)&order=acquired_at.desc")).objects()
            val owned = rows.mapNotNull { r -> r.optJSONObject("products")?.let { Product.from(it) to r.optString("acquired_at") } }
            closet = owned.map { it.first }
            closetAcquiredAt = owned.associate { it.first.id to it.second }
        }
    }

    private suspend fun loadFavorites() {
        runCatching {
            favoriteIds = JSONArray(sb.select("favorites?select=product_id")).objects().map { it.getString("product_id") }.toSet()
        }
    }

    private suspend fun loadRecommendationFeedback() {
        runCatching {
            val rows = JSONArray(sb.select("recommendation_feedback?select=product_id,action")).objects()
            dismissedIds = rows.filter { it.optString("action") == "dismissed" }.map { it.getString("product_id") }.toSet()
            acceptedIds = rows.filter { it.optString("action") == "added_to_cart" }.map { it.getString("product_id") }.toSet()
        }
    }

    suspend fun loadLedger() {
        ledger = JSONArray(sb.select("coin_ledger?select=*&order=created_at.desc&limit=60")).objects().map(LedgerEntry::from)
    }

    // MARK: rewards

    suspend fun claimDaily(): DailyResult? {
        val r = runCatching { DailyResult.from(JSONObject(sb.rpc("claim_daily"))) }.getOrNull() ?: return null
        refreshMe()
        return r
    }

    suspend fun spin(): SpinResult? {
        analytics.track("wheel_spin_start")
        val r = runCatching { SpinResult.from(JSONObject(sb.rpc("spin"))) }.getOrNull() ?: return null
        analytics.track("wheel_spin_result", mapOf("ok" to r.ok, "prize" to (r.prize ?: 0), "slice" to (r.slice ?: -1)))
        return r
    }

    // MARK: recommendations

    fun dismissRecommendation(id: String) {
        dismissedIds = dismissedIds + id
        persistRecommendation(id, "dismissed")
    }

    fun resetRecommendationDismissals() {
        dismissedIds = emptySet()
    }

    private fun persistRecommendation(id: String, action: String) {
        if (authState != AuthState.SIGNED_IN) return
        scope.launch {
            runCatching { sb.rpc("record_recommendation_feedback", JSONObject().put("p_product_id", id).put("p_action", action)) }
        }
    }

    // MARK: cart + checkout

    fun inCart(id: String) = id in cartIds

    fun addToCart(id: String, recommendation: Boolean = false): Boolean {
        if (id in cartIds) return false
        cartIds += id
        analytics.track("add_to_cart", mapOf("product_id" to id, "recommendation" to recommendation) + tasteProps(id))
        if (recommendation) {
            acceptedIds = acceptedIds + id
            persistRecommendation(id, "added_to_cart")
        }
        return true
    }

    fun removeFromCart(id: String) {
        analytics.track("remove_from_cart", mapOf("product_id" to id) + tasteProps(id))
        cartIds.remove(id)
    }

    suspend fun checkout(): PurchaseResult? {
        val ids = cartIds.toList()
        if (ids.isEmpty()) return null
        val total = logic().cartTotal
        analytics.track("checkout_started", mapOf("item_count" to ids.size, "coin_total" to total))
        val r = runCatching { PurchaseResult.from(JSONObject(sb.rpc("purchase_cart", JSONObject().put("p_product_ids", JSONArray(ids))))) }
            .getOrNull() ?: return null
        if (r.ok) {
            (r.bought ?: ids).forEach { analytics.track("checkout_item", mapOf("product_id" to it) + tasteProps(it)) }
            cartIds.clear()
            loadCloset()
            refreshMe()
            analytics.track("checkout_completed", mapOf("item_count" to ids.size, "coin_total" to total))
        }
        return r
    }

    private fun tasteProps(id: String): Map<String, Any?> {
        val p = products.firstOrNull { it.id == id } ?: return emptyMap()
        return mapOf(
            "brand_id" to p.brandId, "category" to p.category, "slot" to p.slot, "color" to p.colorName,
            "price" to p.price, "rarity" to p.rarity, "style_tags" to p.styleTags,
        )
    }

    // MARK: favorites

    suspend fun toggleFavorite(id: String) {
        if (id in favoriteIds) {
            favoriteIds = favoriteIds - id
            try {
                sb.write("favorites?product_id=eq.$id", "DELETE", null)
                analytics.track("unfavorite", mapOf("product_id" to id) + tasteProps(id))
            } catch (e: Throwable) {
                favoriteIds = favoriteIds + id
                throw e
            }
        } else {
            val uid = sb.currentUserId ?: throw SupabaseError.NotAuthenticated
            favoriteIds = favoriteIds + id
            try {
                sb.write("favorites", "POST", JSONObject().put("user_id", uid).put("product_id", id).toString())
                analytics.track("favorite", mapOf("product_id" to id) + tasteProps(id))
            } catch (e: Throwable) {
                favoriteIds = favoriteIds - id
                throw e
            }
        }
    }

    // MARK: purchases

    /** Ask the server to credit any store purchase not yet granted (idempotent by transaction id). */
    suspend fun reconcilePurchases() {
        val ok = runCatching { JSONObject(sb.callFunction("redeem")).optBoolean("ok") }.getOrDefault(false)
        if (ok) refreshMe()
    }

    // MARK: shipping address (device only)

    fun saveAddress(a: ShippingAddress) {
        shipping = a
        prefs.edit().putString(ADDRESS_KEY, JSONObject()
            .put("name", a.name).put("line1", a.line1).put("line2", a.line2).put("city", a.city)
            .put("state", a.state).put("zip", a.zip).put("country", a.country).toString()).apply()
    }

    fun clearAddress() {
        shipping = ShippingAddress()
        prefs.edit().remove(ADDRESS_KEY).apply()
    }

    private fun loadAddress(): ShippingAddress {
        val o = prefs.getString(ADDRESS_KEY, null)?.let { runCatching { JSONObject(it) }.getOrNull() } ?: return ShippingAddress()
        return ShippingAddress(o.optString("name"), o.optString("line1"), o.optString("line2"), o.optString("city"),
            o.optString("state"), o.optString("zip"), o.optString("country", "United States"))
    }

    // MARK: debug

    /** Debug screenshot runs: mark onboarding seen so launch lands on sign-in. */
    fun markOnboardedForDebug() {
        hasCompletedOnboarding = true
        prefs.edit().putBoolean("hasCompletedOnboarding", true).apply()
    }

    companion object {
        private const val GUEST_KEY = "dreamcart.browsingAsGuest"
        private const val ADDRESS_KEY = "dreamcart.shippingAddress"
        const val BRANDS = "brands?select=*&order=sort.asc"
        private const val PRODUCT_QUERY = "products?select=*,brands(*)&is_active=eq.true&order=drop_date.desc,created_at.desc,id.asc"
        /** The first page, small so the tabs appear fast; the rest load behind it. */
        const val PRODUCTS = "$PRODUCT_QUERY&limit=200"
        /** PostgREST caps a response at 1000 rows. */
        private const val PAGE_SIZE = 1000
    }
}
