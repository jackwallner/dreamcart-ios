package com.jackwallner.shop

import com.jackwallner.shop.model.CoinPack
import com.jackwallner.shop.model.PlusPlan
import com.jackwallner.shop.model.Wheel
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The server is the authority on prizes and pack sizes. These read the live
 * tables straight out of the Supabase migrations, the edge functions and the
 * iOS sources, so the Android copy cannot drift from what the backend grants.
 */
class ParityTests {
    private val root = File(System.getProperty("repoRoot") ?: "../..")

    private fun read(path: String) = File(root, path).readText()

    /** The newest migration that (re)defines `spin()` is the one in force. */
    private fun serverWheel(): List<Pair<Int, Int>> {
        val migrations = File(root, "supabase/migrations").listFiles()!!.filter { it.name.endsWith(".sql") }.sortedBy { it.name }
        val latest = migrations.last { it.readText().contains("function public.spin()") }
        val body = latest.readText().substringAfter("function public.spin()").substringBefore("end \$\$")
        return Regex("""prize := (\d+);\s*slice := (\d+);""").findAll(body).map { it.groupValues[2].toInt() to it.groupValues[1].toInt() }.toList()
    }

    @Test fun wheelPrizesMatchTheServerSpinFunctionIndexForIndex() {
        val server = serverWheel()
        assertEquals(Wheel.SLICES, server.size)
        server.forEach { (slice, prize) -> assertEquals("slice $slice", prize, Wheel.PRIZES[slice]) }
    }

    @Test fun wheelPrizesMatchTheIosWheel() {
        val swift = read("DreamCart/Views/SpinView.swift")
        val prizes = Regex("""private let prizes = \[([\d, ]+)]""").find(swift)!!.groupValues[1].split(",").map { it.trim().toInt() }
        assertEquals(prizes, Wheel.PRIZES)
    }

    private fun tsPackMap(path: String): Map<String, Int> {
        val src = read(path)
        return Regex(""""(com\.jackwallner\.shop\.coins\.\w+)":\s*([\d_]+)""").findAll(src)
            .associate { it.groupValues[1] to it.groupValues[2].replace("_", "").toInt() }
    }

    @Test fun coinPacksMatchTheRedeemFunctionGrants() {
        val redeem = tsPackMap("supabase/functions/redeem/index.ts")
        assertEquals(CoinPack.all.associate { it.productId to it.coins }, redeem)
    }

    @Test fun coinPacksMatchTheWebhookGrants() {
        val webhook = tsPackMap("supabase/functions/rc-webhook/index.ts")
        assertEquals(CoinPack.all.associate { it.productId to it.coins }, webhook)
    }

    @Test fun coinPacksMatchTheIosCatalog() {
        val swift = read("Shared/Services/Config.swift")
        val ios = Regex("""productId: "([\w.]+)", coins: (\d+),\s*title: "(\w+)", blurb: "([^"]+)", badge: (nil|"[^"]+")""")
            .findAll(swift).map { m ->
                CoinPack(m.groupValues[1], m.groupValues[2].toInt(), m.groupValues[3], m.groupValues[4], m.groupValues[5].takeIf { it != "nil" }?.trim('"'))
            }.toList()
        assertEquals(5, ios.size)
        assertEquals(ios, CoinPack.all)
    }

    @Test fun plusProductIsTheOneTheWebhookFlipsAndIosSells() {
        assertTrue(read("supabase/functions/rc-webhook/index.ts").contains("\"${PlusPlan.PRODUCT_ID}\""))
        val swift = read("Shared/Services/Config.swift")
        assertTrue(swift.contains("static let productId = \"${PlusPlan.PRODUCT_ID}\""))
        assertTrue(swift.contains("static let trialDays = ${PlusPlan.TRIAL_DAYS}"))
    }

    @Test fun webhookAcceptsPlayBasePlanProductIds() {
        // RevenueCat names a Play subscription `<subscriptionId>:<basePlanId>`.
        val src = read("supabase/functions/rc-webhook/index.ts")
        assertTrue("rc-webhook must strip the Play base plan suffix", src.contains("split(\":\")[0]"))
    }

    @Test fun onboardingAndPaywallCopyMatchIos() {
        val welcome = read("DreamCart/Views/WelcomeView.swift")
        listOf("Shop without the guilt", "Free coins every day", "Build your dream closet").forEach { assertTrue(it, welcome.contains(it)) }
        val plus = read("DreamCart/Views/PlusOfferView.swift")
        listOf("Every day counts double, and the wheel never stops.", "Double coins every single day", "Spin the wheel as often as you like", "Fill your closet twice as fast")
            .forEach { assertTrue(it, plus.contains(it)) }
    }
}
