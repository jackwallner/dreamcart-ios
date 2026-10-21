package com.jackwallner.shop.model

import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/** `CoinPack`: product ids match ASC, Play, RevenueCat and the redeem/webhook maps. */
data class CoinPack(val productId: String, val coins: Int, val title: String, val blurb: String, val badge: String?) {
    /** Shown only until the store answers. Never used in a purchase. */
    val fallbackPrice: String
        get() = when (title) {
            "Pocket" -> "$1.99"
            "Bag" -> "$4.99"
            "Haul" -> "$9.99"
            "Spree" -> "$19.99"
            else -> "$49.99"
        }

    companion object {
        val all = listOf(
            CoinPack("com.jackwallner.shop.coins.pocket", 1000, "Pocket", "A little treat", null),
            CoinPack("com.jackwallner.shop.coins.bag", 3200, "Bag", "One full look", "POPULAR"),
            CoinPack("com.jackwallner.shop.coins.haul", 8500, "Haul", "A whole wardrobe", null),
            CoinPack("com.jackwallner.shop.coins.spree", 20000, "Spree", "Go all out", "BEST VALUE"),
            CoinPack("com.jackwallner.shop.coins.vault", 60000, "Vault", "Never run dry", null),
        )

        /** The pack showcased in upsell moments: the catalog's own POPULAR pick. */
        val recommended: CoinPack get() = all.firstOrNull { it.badge == "POPULAR" } ?: all[all.size / 2]
    }
}

/** DreamCart+, the weekly membership. `is_plus` is set server-side by the RevenueCat webhook. */
object PlusPlan {
    const val PRODUCT_ID = "com.jackwallner.shop.plus.weekly"
    /** The Play base plan; RevenueCat names the Play product `<subscription>:<base plan>`. */
    const val BASE_PLAN_ID = "weekly"
    const val NAME = "DreamCart+"
    const val TRIAL_DAYS = 3
    const val CONVERSION_PLAN = "weekly"
    const val MANAGE_URL = "https://play.google.com/store/account/subscriptions?sku=$PRODUCT_ID&package=com.jackwallner.shop"

    fun headline(trialEligible: Boolean) = if (trialEligible) "Try $NAME free" else "Get $NAME"

    fun cta(trialEligible: Boolean) = if (trialEligible) "Start $TRIAL_DAYS-day free trial" else "Get $NAME"

    /** `PlusOfferView.disclosure`, with Play's cancel path in place of iOS Settings. */
    fun disclosure(price: String?, trialEligible: Boolean): String = when {
        price == null && trialEligible -> "$TRIAL_DAYS days free, then a weekly charge. Auto-renews until canceled."
        price == null -> "Billed weekly. Auto-renews until canceled."
        trialEligible -> "$TRIAL_DAYS days free, then $price per week. Auto-renews until canceled. Cancel anytime in Google Play."
        else -> "$price per week. Auto-renews until canceled. Cancel anytime in Google Play."
    }
}

/** The prize wheel. Slice i pays [PRIZES][i]; must match the server's `spin()` index for index. */
object Wheel {
    val PRIZES = listOf(800, 1500, 2000, 2500, 3500, 5000, 7500, 12000)
    val SLICES = PRIZES.size

    enum class Tier { SMALL, BIG, JACKPOT }

    fun tier(prize: Int): Tier {
        if (prize == PRIZES.max()) return Tier.JACKPOT
        val median = PRIZES.sorted()[PRIZES.size / 2]
        return if (prize >= median) Tier.BIG else Tier.SMALL
    }

    /**
     * Final wheel rotation, in degrees, that parks [slice] under the top pointer
     * after [turns] full spins from [current]. Slice 0 is centred at 0 degrees and
     * slices run clockwise, so the wheel turns back by the slice's centre angle.
     */
    fun targetRotation(current: Float, slice: Int, turns: Int = 6): Float {
        val per = 360f / SLICES
        val sliceCentre = slice * per
        val base = current - (current % 360f)
        return base + turns * 360f + (360f - sliceCentre) % 360f
    }
}

object Format {
    fun coins(n: Int): String = NumberFormat.getIntegerInstance(Locale.US).format(n)

    fun coinsShort(n: Int): String {
        if (n < 1000) return n.toString()
        val k = n / 1000.0
        val raw = if (k >= 10) String.format(Locale.US, "%.0fk", k) else String.format(Locale.US, "%.1fk", k)
        return raw.replace(".0k", "k")
    }
}

/** A pretend delivery address for the fake checkout. Saved on the device only. */
data class ShippingAddress(
    val name: String = "",
    val line1: String = "",
    val line2: String = "",
    val city: String = "",
    val state: String = "",
    val zip: String = "",
    val country: String = "United States",
) {
    val isValid: Boolean get() = listOf(name, line1, city).all { it.isNotBlank() }
    val isEmpty: Boolean get() = listOf(name, line1, line2, city, state, zip).all { it.isBlank() }

    val multilineSummary: String
        get() {
            val lines = mutableListOf(name, line1)
            if (line2.isNotBlank()) lines += line2
            val cityState = listOf(city, state).filter { it.isNotBlank() }.joinToString(", ")
            val cityStateZip = listOf(cityState, zip).filter { it.isNotBlank() }.joinToString(" ")
            if (cityStateZip.isNotBlank()) lines += cityStateZip
            if (country.isNotBlank()) lines += country
            return lines.filter { it.isNotBlank() }.joinToString("\n")
        }

    val shortSummary: String
        get() = if (!isValid) "Add an address for checkout" else listOf(city, state).filter { it.isNotBlank() }.joinToString(", ")
}

/** Shop filter chips, in iOS order. */
data class CategoryChip(val key: String, val label: String)

object Categories {
    val shop = listOf(
        CategoryChip("top", "Tops"), CategoryChip("bottom", "Bottoms"), CategoryChip("dress", "Dresses"),
        CategoryChip("outerwear", "Outerwear"), CategoryChip("shoes", "Shoes"), CategoryChip("bag", "Bags"),
        CategoryChip("jewelry", "Jewelry"), CategoryChip("sunglasses", "Shades"), CategoryChip("hat", "Hats"),
        CategoryChip("accessory", "Extras"),
    )

    /** `ClosetView.categoryLabel(_:)`. */
    fun label(category: String): String = when (category) {
        "headwear", "hat" -> "Hats"
        "eyewear", "sunglasses" -> "Shades"
        "footwear", "shoes" -> "Shoes"
        "top" -> "Tops"
        "bottom" -> "Bottoms"
        "dress" -> "Dresses"
        "outerwear" -> "Outerwear"
        "bag" -> "Bags"
        "jewelry" -> "Jewelry"
        "accessory" -> "Extras"
        else -> category.replaceFirstChar { it.uppercase() }
    }
}

enum class ClosetSort(val label: String) { NEWEST("Newest"), NAME("Name"), PRICE_HIGH("Price: high to low"), PRICE_LOW("Price: low to high") }

/**
 * The pure half of iOS `ShopStore`: catalog queries, cart math and the For You
 * ranking. No I/O, so the JVM tests drive it exactly like DreamCartTests does.
 */
class CatalogLogic(
    val products: List<Product>,
    val ownedIds: Set<String> = emptySet(),
    val favoriteIds: Set<String> = emptySet(),
    val dismissedIds: Set<String> = emptySet(),
    val acceptedIds: Set<String> = emptySet(),
    val cartIds: List<String> = emptyList(),
    val today: String = todayUTC(),
) {
    private val byId = products.associateBy { it.id }

    val cartProducts: List<Product> get() = cartIds.mapNotNull { byId[it] }
    val cartTotal: Int get() = cartProducts.sumOf { it.price }
    fun canAfford(coins: Int) = cartTotal <= coins

    val newDropIds: Set<String> get() = products.filter { it.dropDate == today }.map { it.id }.toSet()

    /** Newest 20 by drop date; a stable sort keeps catalog order within a day, like Swift's sort on this data. */
    val newDrops: List<Product> get() = products.sortedByDescending { it.dropDate ?: "" }.take(20)

    fun byBrand(brandId: String) = products.filter { it.brandId == brandId }
    fun byCategory(category: String) = products.filter { it.category == category }

    fun search(query: String): List<Product> {
        val t = query.trim().lowercase()
        if (t.isEmpty()) return emptyList()
        return products.filter { p ->
            p.name.lowercase().contains(t) ||
                p.colorName.lowercase().contains(t) ||
                p.category.lowercase().contains(t) ||
                (p.brand?.name?.lowercase()?.contains(t) ?: false) ||
                p.styleTags.any { it.lowercase().contains(t) }
        }
    }

    fun forYou(limit: Int = 30) = ranked(anchor = null, preferDifferentSlots = false, limit = limit)

    fun complementary(anchor: Product, limit: Int = 6) = ranked(anchor, preferDifferentSlots = true, limit = limit)

    private fun ranked(anchor: Product?, preferDifferentSlots: Boolean, limit: Int): List<Product> {
        val positive = products.filter { it.id in ownedIds || it.id in favoriteIds || it.id in acceptedIds }
        val candidates = products.filter {
            it.id != anchor?.id && it.id !in ownedIds && it.id !in cartIds && it.id !in dismissedIds
        }
        val drops = newDropIds
        val scored = candidates.mapIndexed { index, c -> Triple(c, score(c, anchor, positive, preferDifferentSlots, drops), index) }
            .sortedWith(compareByDescending<Triple<Product, Int, Int>> { it.second }.thenBy { it.third })

        val result = mutableListOf<Product>()
        val slotCounts = mutableMapOf<String, Int>()
        val brandCounts = mutableMapOf<String, Int>()
        val slotCap = if (preferDifferentSlots) 1 else 4
        for ((candidate) in scored) {
            if ((slotCounts[candidate.slot] ?: 0) >= slotCap || (brandCounts[candidate.brandId] ?: 0) >= 5) continue
            result += candidate
            slotCounts[candidate.slot] = (slotCounts[candidate.slot] ?: 0) + 1
            brandCounts[candidate.brandId] = (brandCounts[candidate.brandId] ?: 0) + 1
            if (result.size == limit) break
        }
        return result
    }

    private fun score(c: Product, anchor: Product?, positive: List<Product>, preferDifferentSlots: Boolean, drops: Set<String>): Int {
        val references = anchor?.let { listOf(it) } ?: positive
        var score = 0
        for (r in references) {
            if (c.brandId == r.brandId) score += 8
            if (c.category == r.category) score += 4
            if (c.slot == r.slot) score += if (preferDifferentSlots) -12 else 4
            else if (preferDifferentSlots) score += 10
            score += c.styleTags.toSet().intersect(r.styleTags.toSet()).size * 6
            if (c.colorName.equals(r.colorName, ignoreCase = true)) score += 3
        }
        if (c.id in favoriteIds) score += 12
        if (c.id in acceptedIds) score += 10
        if (c.id in drops) score += 2
        score += when (c.rarityKind) {
            Rarity.LEGENDARY -> 2
            Rarity.EPIC -> 1
            else -> 0
        }
        return score
    }

    companion object {
        /** `appendCatalogPage`: append a page, dropping ids already loaded or repeated. */
        fun appendPage(existing: List<Product>, page: List<Product>): List<Product> {
            val seen = existing.map { it.id }.toMutableSet()
            return existing + page.filter { seen.add(it.id) }
        }

        /** Today in UTC as "YYYY-MM-DD", matching the database's `current_date`. */
        fun todayUTC(nowMillis: Long = System.currentTimeMillis()): String {
            val c = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { timeInMillis = nowMillis }
            return String.format(Locale.US, "%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
        }
    }
}

/** `TodayView.greeting`. */
fun greeting(hour: Int): String = when (hour) {
    in 5..11 -> "Good morning"
    in 12..16 -> "Good afternoon"
    in 17..21 -> "Good evening"
    else -> "Late-night haul"
}

/** `CheckoutView.failureMessage(for:)`. */
fun checkoutFailureMessage(reason: String?): String = when (reason) {
    "insufficient_coins" -> "You don't have enough coins for this order."
    "nothing_to_buy" -> "Your cart looks empty. Add something first."
    else -> "Couldn't place your order. Try again."
}

/** `AppRoute`: dreamcart://new-drops and dreamcart://shop. */
enum class AppRoute(val raw: String) {
    NEW_DROPS("new-drops"), SHOP("shop");

    companion object {
        fun parse(uri: String?): AppRoute? {
            if (uri == null || !uri.startsWith("dreamcart://")) return null
            val host = uri.removePrefix("dreamcart://").substringBefore('/').substringBefore('?')
            return entries.firstOrNull { it.raw == host }
        }
    }
}
