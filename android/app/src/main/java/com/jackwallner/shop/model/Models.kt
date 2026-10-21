package com.jackwallner.shop.model

import org.json.JSONArray
import org.json.JSONObject

// Wire models mirroring the Supabase schema, the same rows iOS decodes in
// Shared/Models/Models.swift. Parsed with org.json, which ships with Android.

data class Brand(
    val id: String,
    val slug: String,
    val name: String,
    val tagline: String,
    val accentHex: String,
    val bgHex: String,
    val sort: Int,
) {
    companion object {
        fun from(o: JSONObject) = Brand(
            id = o.getString("id"),
            slug = o.optString("slug"),
            name = o.optString("name"),
            tagline = o.optString("tagline"),
            accentHex = o.optString("accent_hex", "#7C3AED"),
            bgHex = o.optString("bg_hex", "#FFFFFF"),
            sort = o.optInt("sort"),
        )
    }
}

/** A catalog product, with its brand row when the query embedded it (`ProductWithBrand` on iOS). */
data class Product(
    val id: String,
    val brandId: String,
    val name: String,
    val category: String,
    val slot: String,
    val styleTags: List<String>,
    val colorName: String,
    val price: Int,
    val rarity: String,
    val description: String,
    val imageUrl: String,
    val dropDate: String?,
    val brand: Brand? = null,
) {
    val rarityKind: Rarity get() = Rarity.from(rarity)

    companion object {
        fun from(o: JSONObject): Product {
            val tags = o.optJSONArray("style_tags") ?: JSONArray()
            return Product(
                id = o.getString("id"),
                brandId = o.optString("brand_id"),
                name = o.optString("name"),
                category = o.optString("category"),
                slot = o.optString("slot"),
                styleTags = List(tags.length()) { tags.optString(it) },
                colorName = o.optString("color_name"),
                price = o.optInt("price"),
                rarity = o.optString("rarity", "common"),
                description = o.optString("description"),
                imageUrl = o.optString("image_url"),
                dropDate = o.optStringOrNull("drop_date"),
                brand = o.optJSONObject("brands")?.let(Brand::from),
            )
        }
    }
}

/** From the `me()` RPC: the authoritative snapshot of the signed-in user. */
data class MeSnapshot(
    val id: String,
    val displayName: String,
    val coins: Int,
    val streak: Int,
    val bestStreak: Int,
    val isPlus: Boolean,
    val lifetimeSpent: Int,
    val itemsOwned: Int,
    val canClaimDaily: Boolean,
    val canSpin: Boolean,
) {
    companion object {
        fun from(o: JSONObject) = MeSnapshot(
            id = o.optString("id"),
            displayName = o.optString("display_name"),
            coins = o.optInt("coins"),
            streak = o.optInt("streak"),
            bestStreak = o.optInt("best_streak"),
            isPlus = o.optBoolean("is_plus"),
            lifetimeSpent = o.optInt("lifetime_spent"),
            itemsOwned = o.optInt("items_owned"),
            canClaimDaily = o.optBoolean("can_claim_daily"),
            canSpin = o.optBoolean("can_spin"),
        )
    }
}

data class DailyResult(val ok: Boolean, val reason: String?, val granted: Int?, val coins: Int, val streak: Int?, val weeklyBonus: Boolean) {
    companion object {
        fun from(o: JSONObject) = DailyResult(
            ok = o.optBoolean("ok"),
            reason = o.optStringOrNull("reason"),
            granted = o.optIntOrNull("granted"),
            coins = o.optInt("coins"),
            streak = o.optIntOrNull("streak"),
            weeklyBonus = o.optBoolean("weekly_bonus"),
        )
    }
}

data class SpinResult(val ok: Boolean, val reason: String?, val prize: Int?, val slice: Int?, val coins: Int) {
    companion object {
        fun from(o: JSONObject) = SpinResult(
            ok = o.optBoolean("ok"),
            reason = o.optStringOrNull("reason"),
            prize = o.optIntOrNull("prize"),
            slice = o.optIntOrNull("slice"),
            coins = o.optInt("coins"),
        )
    }
}

data class PurchaseResult(val ok: Boolean, val reason: String?, val spent: Int?, val coins: Int, val need: Int?, val bought: List<String>?) {
    companion object {
        fun from(o: JSONObject): PurchaseResult {
            val bought = o.optJSONArray("bought")
            return PurchaseResult(
                ok = o.optBoolean("ok"),
                reason = o.optStringOrNull("reason"),
                spent = o.optIntOrNull("spent"),
                coins = o.optInt("coins"),
                need = o.optIntOrNull("need"),
                bought = bought?.let { a -> List(a.length()) { a.optString(it) } },
            )
        }
    }
}

data class LedgerEntry(val id: Long, val delta: Int, val reason: String, val balanceAfter: Int, val createdAt: String) {
    /** `LedgerView.label(_:)`. */
    val label: String
        get() = when (reason) {
            "welcome" -> "Welcome bonus"
            "daily" -> "Daily drop"
            "spin" -> "Spin the wheel"
            "checkout" -> "Shopping"
            "pack" -> "Coin pack"
            else -> reason.replaceFirstChar { it.uppercase() }
        }

    companion object {
        fun from(o: JSONObject) = LedgerEntry(
            id = o.optLong("id"),
            delta = o.optInt("delta"),
            reason = o.optString("reason"),
            balanceAfter = o.optInt("balance_after"),
            createdAt = o.optString("created_at"),
        )
    }
}

enum class Rarity(val label: String) {
    COMMON("Common"), RARE("Rare"), EPIC("Epic"), LEGENDARY("Legendary");

    val glow: Boolean get() = this == EPIC || this == LEGENDARY

    companion object {
        fun from(raw: String): Rarity = entries.firstOrNull { it.name.equals(raw, ignoreCase = true) } ?: COMMON
    }
}

fun JSONObject.optStringOrNull(key: String): String? = if (isNull(key) || !has(key)) null else optString(key)
fun JSONObject.optIntOrNull(key: String): Int? = if (isNull(key) || !has(key)) null else optInt(key)

fun JSONArray.objects(): List<JSONObject> = List(length()) { getJSONObject(it) }
