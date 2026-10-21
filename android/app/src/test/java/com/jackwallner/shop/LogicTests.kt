package com.jackwallner.shop

import com.jackwallner.shop.data.ConversionDiagnostics
import com.jackwallner.shop.data.KeyValueStore
import com.jackwallner.shop.model.AppRoute
import com.jackwallner.shop.model.CatalogLogic
import com.jackwallner.shop.model.Categories
import com.jackwallner.shop.model.CoinPack
import com.jackwallner.shop.model.DailyResult
import com.jackwallner.shop.model.Format
import com.jackwallner.shop.model.LedgerEntry
import com.jackwallner.shop.model.MeSnapshot
import com.jackwallner.shop.model.PlusPlan
import com.jackwallner.shop.model.Product
import com.jackwallner.shop.model.PurchaseResult
import com.jackwallner.shop.model.Rarity
import com.jackwallner.shop.model.ShippingAddress
import com.jackwallner.shop.model.SpinResult
import com.jackwallner.shop.model.Wheel
import com.jackwallner.shop.model.checkoutFailureMessage
import com.jackwallner.shop.model.greeting
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Ports of DreamCartTests.swift plus the Android-only pieces (wheel landing, JSON, funnel). */
class LogicTests {
    private fun product(
        id: String, price: Int = 100, name: String = "Item", color: String = "Black",
        styleTags: List<String> = listOf("minimal"), slot: String = "top", dropDate: String? = null,
    ) = Product(id, "b1", name, slot, slot, styleTags, color, price, "common", "", "", dropDate)

    @Test fun coinFormatting() {
        assertEquals("1,000", Format.coins(1000))
        assertEquals("1,234,567", Format.coins(1234567))
        assertEquals("950", Format.coinsShort(950))
        assertEquals("1k", Format.coinsShort(1000))
        assertEquals("12k", Format.coinsShort(12400))
        assertEquals("3.2k", Format.coinsShort(3200))
    }

    @Test fun rarityMapping() {
        assertEquals(Rarity.LEGENDARY, Rarity.from("legendary"))
        assertEquals(Rarity.COMMON, Rarity.from("nonsense"))
        assertTrue(Rarity.EPIC.glow)
        assertFalse(Rarity.COMMON.glow)
    }

    @Test fun coinPackCatalogIntegrity() {
        val ids = CoinPack.all.map { it.productId }
        assertEquals(ids.toSet().size, ids.size)
        assertTrue("com.jackwallner.shop.coins.pocket" in ids)
        assertTrue("com.jackwallner.shop.coins.vault" in ids)
        assertEquals(5, CoinPack.all.size)
        val coins = CoinPack.all.map { it.coins }
        assertEquals(coins.sorted(), coins)
        assertEquals("Bag", CoinPack.recommended.title)
    }

    @Test fun cartMathAndAffordability() {
        val products = listOf(product("a", 300), product("b", 500), product("c", 250))
        val ab = CatalogLogic(products, cartIds = listOf("a", "b"))
        assertEquals(800, ab.cartTotal)
        assertFalse(ab.canAfford(700))
        val ac = CatalogLogic(products, cartIds = listOf("a", "c"))
        assertEquals(550, ac.cartTotal)
        assertTrue(ac.canAfford(700))
    }

    @Test fun cartKeepsInsertionOrderAndSkipsUnknownIds() {
        val logic = CatalogLogic(listOf(product("a"), product("b")), cartIds = listOf("b", "gone", "a"))
        assertEquals(listOf("b", "a"), logic.cartProducts.map { it.id })
    }

    @Test fun search() {
        val logic = CatalogLogic(listOf(product("x", name = "Verona Emerald Slip Dress", color = "Emerald"), product("y", name = "Nova Camel Trench", color = "Camel")))
        assertEquals(listOf("x"), logic.search("emerald").map { it.id })
        assertEquals(listOf("y"), logic.search("camel").map { it.id })
        assertTrue(logic.search("zzz").isEmpty())
        assertTrue(logic.search("   ").isEmpty())
        assertEquals(2, logic.search("minimal").size)
    }

    @Test fun forYouExcludesOwnedCartedAndDismissedProducts() {
        val logic = CatalogLogic(
            listOf(product("owned"), product("cart"), product("dismissed"), product("eligible")),
            ownedIds = setOf("owned"), dismissedIds = setOf("dismissed"), cartIds = listOf("cart"),
        )
        assertEquals(listOf("eligible"), logic.forYou().map { it.id })
    }

    @Test fun recommendationsPreferMatchingStyleAndDifferentComplementarySlot() {
        val anchor = product("anchor", slot = "top")
        val logic = CatalogLogic(listOf(anchor, product("same-slot", slot = "top"), product("shoes", slot = "footwear"), product("random", styleTags = listOf("party"), slot = "bottom")))
        assertEquals("shoes", logic.complementary(anchor).first().id)
    }

    @Test fun forYouCapsFourPerSlotAndFivePerBrand() {
        val many = (1..12).map { product("t$it", slot = "top") }
        val picks = CatalogLogic(many).forYou()
        assertEquals(4, picks.size)
    }

    @Test fun catalogPageDeduplicatesProducts() {
        val merged = CatalogLogic.appendPage(listOf(product("a")), listOf(product("a"), product("b", 200), product("b", 200)))
        assertEquals(listOf("a", "b"), merged.map { it.id })
    }

    @Test fun newDropsUseTheUtcDayAndNewestFirst() {
        val logic = CatalogLogic(listOf(product("old", dropDate = "2026-01-01"), product("today", dropDate = "2026-10-20"), product("none")), today = "2026-10-20")
        assertEquals(setOf("today"), logic.newDropIds)
        assertEquals("today", logic.newDrops.first().id)
        assertEquals("2026-10-20", CatalogLogic.todayUTC(1792539000000L))
    }

    @Test fun routeParsing() {
        assertEquals(AppRoute.NEW_DROPS, AppRoute.parse("dreamcart://new-drops"))
        assertEquals(AppRoute.SHOP, AppRoute.parse("dreamcart://shop"))
        assertNull(AppRoute.parse("dreamcart://unknown"))
        assertNull(AppRoute.parse("https://shop"))
        assertNull(AppRoute.parse(null))
    }

    @Test fun wheelLandsEverySliceUnderThePointer() {
        var current = 0f
        for (slice in 0 until Wheel.SLICES) {
            val target = Wheel.targetRotation(current, slice)
            assertTrue("spins forward", target > current + 360f * 5)
            // Slice centre angle plus the rotation must sit at 12 o'clock.
            val landed = ((slice * 360f / Wheel.SLICES + target) % 360f + 360f) % 360f
            assertEquals(0f, minOf(landed, 360f - landed), 0.01f)
            current = target
        }
    }

    @Test fun wheelTiers() {
        assertEquals(Wheel.Tier.JACKPOT, Wheel.tier(12000))
        assertEquals(Wheel.Tier.BIG, Wheel.tier(3500))
        assertEquals(Wheel.Tier.SMALL, Wheel.tier(800))
    }

    @Test fun plusCopyNeverPromisesATrialToTheIneligible() {
        assertEquals("Try DreamCart+ free", PlusPlan.headline(true))
        assertEquals("Get DreamCart+", PlusPlan.headline(false))
        assertEquals("Start 3-day free trial", PlusPlan.cta(true))
        assertFalse(PlusPlan.disclosure("$0.99", false).contains("free"))
        assertTrue(PlusPlan.disclosure("$0.99", true).startsWith("3 days free, then $0.99 per week."))
        assertTrue(PlusPlan.disclosure("$0.99", true).contains("Google Play"))
        assertFalse(PlusPlan.disclosure(null, false).contains("$"))
        assertTrue(PlusPlan.MANAGE_URL.contains("sku=com.jackwallner.shop.plus.weekly") && PlusPlan.MANAGE_URL.contains("package=com.jackwallner.shop"))
    }

    @Test fun shippingAddressValidationAndSummary() {
        assertFalse(ShippingAddress().isValid)
        assertTrue(ShippingAddress().isEmpty)
        val a = ShippingAddress(name = "Ava", line1 = "1 Dream St", city = "Seattle", state = "WA", zip = "98101")
        assertTrue(a.isValid)
        assertEquals("Ava\n1 Dream St\nSeattle, WA 98101\nUnited States", a.multilineSummary)
        assertEquals("Seattle, WA", a.shortSummary)
    }

    @Test fun checkoutFailureCopy() {
        assertEquals("You don't have enough coins for this order.", checkoutFailureMessage("insufficient_coins"))
        assertEquals("Your cart looks empty. Add something first.", checkoutFailureMessage("nothing_to_buy"))
        assertEquals("Couldn't place your order. Try again.", checkoutFailureMessage(null))
    }

    @Test fun greetingByHour() {
        assertEquals("Good morning", greeting(5))
        assertEquals("Good afternoon", greeting(12))
        assertEquals("Good evening", greeting(21))
        assertEquals("Late-night haul", greeting(2))
    }

    @Test fun categoryLabels() {
        assertEquals("Shades", Categories.label("sunglasses"))
        assertEquals("Hats", Categories.label("headwear"))
        assertEquals("Extras", Categories.label("accessory"))
        assertEquals(10, Categories.shop.size)
    }

    @Test fun decodesServerRows() {
        val p = Product.from(JSONObject("""{"id":"p1","brand_id":"b1","name":"Halo Tote","category":"bag","slot":"bag","style_tags":["minimal","luxe"],"color_name":"Ivory","price":1800,"rarity":"epic","description":"d","image_url":"https://image.pollinations.ai/x","drop_date":null,"brands":{"id":"b1","slug":"halo","name":"Halo","tagline":"t","accent_hex":"#FF3D8B","bg_hex":"#FFF","sort":1}}"""))
        assertEquals(listOf("minimal", "luxe"), p.styleTags)
        assertNull(p.dropDate)
        assertEquals("Halo", p.brand?.name)
        assertEquals(Rarity.EPIC, p.rarityKind)

        val me = MeSnapshot.from(JSONObject("""{"id":"u","display_name":"Ava","coins":5400,"streak":3,"best_streak":9,"is_plus":false,"lifetime_spent":0,"items_owned":4,"can_claim_daily":true,"can_spin":false,"last_daily_claim":null,"last_spin_date":"2026-10-20"}"""))
        assertEquals(5400, me.coins)
        assertTrue(me.canClaimDaily)
        assertFalse(me.canSpin)

        val daily = DailyResult.from(JSONObject("""{"ok":true,"granted":3000,"coins":8400,"streak":4,"weekly_bonus":false}"""))
        assertEquals(3000, daily.granted)
        val spun = SpinResult.from(JSONObject("""{"ok":false,"reason":"spun_today","coins":10}"""))
        assertEquals("spun_today", spun.reason)
        assertNull(spun.slice)
        val bought = PurchaseResult.from(JSONObject("""{"ok":true,"spent":800,"coins":100,"bought":["a","b"]}"""))
        assertEquals(listOf("a", "b"), bought.bought)
        assertEquals("Daily drop", LedgerEntry.from(JSONObject("""{"id":1,"delta":3000,"reason":"daily","balance_after":3000,"created_at":"2026-10-20T00:00:00Z"}""")).label)
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

    @Test fun conversionFunnelMatchesTheFleetAttributes() {
        var now = 1_792_000_000_000L
        val d = ConversionDiagnostics(MapStore()) { now }
        d.recordAppOpen()
        d.recordAppOpen()
        assertTrue(d.subscriberAttributes.isEmpty())
        now += 2 * 86_400_000L
        d.recordPitchView("dreamcart_coin_shop")
        d.recordPitchView("dreamcart_onboarding_plus")
        val a = d.subscriberAttributes
        assertEquals("2", a["pitch_views_total"])
        assertEquals("1", a["pitch_views_coin_shop"])
        assertEquals("onboarding_plus", a["pitch_last"])
        assertEquals("2", a["opens_before_first_pitch"])
        assertEquals("2", a["days_since_install"])
        d.recordConversion("weekly", startedTrial = true)
        d.recordConversion("com.jackwallner.shop.coins.bag", startedTrial = false)
        val c = d.subscriberAttributes
        assertEquals("onboarding_plus", c["converted_surface"])
        assertEquals("weekly", c["converted_plan"])
        assertEquals("true", c["converted_with_trial"])
        assertEquals("2", c["pitch_views_at_convert"])
    }
}
