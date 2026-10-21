package com.jackwallner.shop

import android.content.Intent
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * First-run, guest, and signed-in paths against the real Supabase project.
 * Each test starts from cleared app data (orchestrator `clearPackageData`).
 * The signed-in tests use the shared debug tester account, never a purchase.
 */
@OptIn(ExperimentalTestApi::class)
@RunWith(AndroidJUnit4::class)
class DreamCartFlowTests {
    @get:Rule val compose = createEmptyComposeRule()
    private var scenario: ActivityScenario<MainActivity>? = null
    private val slow = 90_000L

    private fun launch(vararg flags: String) {
        val intent = Intent(ApplicationProvider.getApplicationContext(), MainActivity::class.java)
        flags.forEach { intent.putExtra(it, true) }
        scenario = ActivityScenario.launch(intent)
    }

    @After fun close() { scenario?.close() }

    @Test fun firstLaunchWalksOnboardingToSignInWithGuestOption() {
        launch()
        compose.waitUntilExactlyOneExists(hasText("Shop without the guilt"), slow)
        compose.onNodeWithTag("onboardingNext").performClick()
        compose.waitUntilExactlyOneExists(hasText("Free coins every day"), slow)
        compose.onNodeWithTag("onboardingNext").performClick()
        compose.waitUntilExactlyOneExists(hasText("Get started"), slow)
        compose.onNodeWithTag("onboardingNext").performClick()
        compose.waitUntilAtLeastOneExists(hasTestTag("guestBrowse"), slow)
        compose.onNodeWithText("Privacy Policy").assertExists()
    }

    @Test fun guestBrowsesTheLiveCatalogButTheCartNeedsAnAccount() {
        launch("onboarded", "guest")
        compose.waitUntilAtLeastOneExists(hasTestTag("tabBar"), slow)
        // Guests see real products from the anon-readable catalog.
        compose.waitUntilAtLeastOneExists(hasText("Just dropped"), slow)
        compose.onNodeWithTag("headerSignIn").assertExists()
        compose.onNodeWithTag("tab-CART").performClick()
        compose.waitUntilExactlyOneExists(hasText("The cart needs an account"), slow)
        compose.onNodeWithTag("gateSignIn").performClick()
        compose.waitUntilExactlyOneExists(hasTestTag("signInPrompt"), slow)
        compose.onNodeWithText("Save your haul").assertExists()
        compose.onNodeWithTag("signInNotNow").performClick()
        compose.waitUntilDoesNotExist(hasTestTag("signInPrompt"), slow)
    }

    @Test fun guestAddToCartAsksForSignInInsteadOfAdding() {
        launch("onboarded", "guest")
        compose.waitUntilAtLeastOneExists(hasText("Just dropped"), slow)
        compose.onAllNodes(tagPrefix("product-")).onFirst().performClick()
        compose.waitUntilExactlyOneExists(hasTestTag("addToCart"), slow)
        compose.onNodeWithTag("addToCart").performClick()
        compose.waitUntilExactlyOneExists(hasTestTag("signInPrompt"), slow)
    }

    @Test fun signedInTesterSeesWalletDailyDropAndCoinPacks() {
        launch("onboarded", "tester")
        compose.waitUntilExactlyOneExists(hasTestTag("walletPill"), slow)
        compose.waitUntilAtLeastOneExists(hasTestTag("dailyCard") or hasTestTag("dailyClaimed"), slow)
        compose.onNodeWithTag("walletPill").performClick()
        compose.waitUntilExactlyOneExists(hasTestTag("coinShop"), slow)
        listOf("Pocket", "Bag", "Haul", "Spree", "Vault").forEach { compose.onNodeWithTag("pack-$it").assertExists() }
        compose.onNodeWithText("Coins are for use inside DreamCart only and have no cash value. All items and delivery are virtual.").assertExists()
    }

    @Test fun onboardingThenSignInShowsThePlusOfferWithRenewalTermsAndItCanBeSkipped() {
        launch()
        repeat(3) {
            compose.waitUntilExactlyOneExists(hasTestTag("onboardingNext"), slow)
            compose.onNodeWithTag("onboardingNext").performClick()
        }
        compose.waitUntilExactlyOneExists(hasTestTag("testerSignIn"), slow)
        compose.onNodeWithTag("testerSignIn").performClick()
        compose.waitUntilExactlyOneExists(hasTestTag("plusOffer"), slow)
        compose.waitUntilExactlyOneExists(hasText("Auto-renews until canceled", substring = true), slow)
        compose.onNodeWithText("Double coins every single day").assertExists()
        compose.onNodeWithTag("plusRestore").assertExists()
        compose.onNodeWithTag("plusSkip").performClick()
        compose.waitUntilExactlyOneExists(hasTestTag("tabBar"), slow)
    }

    @Test fun profileShowsTheOfferToFreeUsersAndManageToMembers() {
        launch("onboarded", "tester")
        compose.waitUntilExactlyOneExists(hasTestTag("walletPill"), slow)
        compose.onNodeWithTag("tab-PROFILE").performClick()
        compose.waitUntilExactlyOneExists(hasTestTag("profilePlus") or hasTestTag("profilePlusActive"), slow)
        val member = compose.onAllNodes(hasTestTag("profilePlusActive")).fetchSemanticsNodes().isNotEmpty()
        if (member) {
            compose.onNodeWithText("Active · manage or cancel in Google Play").assertExists()
        } else {
            compose.onNodeWithTag("profilePlus").performClick()
            compose.waitUntilExactlyOneExists(hasTestTag("plusOffer"), slow)
        }
    }

    @Test fun checkoutWaitsForAnAddressOrSkip() {
        launch("onboarded", "tester")
        compose.waitUntilAtLeastOneExists(hasText("Just dropped"), slow)
        // Pick a piece the tester does not own yet.
        val nodes = compose.onAllNodes(tagPrefix("product-") and !hasText("Owned"))
        nodes.onFirst().performClick()
        compose.waitUntilExactlyOneExists(hasTestTag("addToCart"), slow)
        compose.onNodeWithTag("addToCart").performClick()
        compose.waitUntilExactlyOneExists(hasText("Go to checkout"), slow)
        compose.onNodeWithTag("addToCart").performClick()
        compose.waitUntilExactlyOneExists(hasTestTag("checkout"), slow)
        compose.onNodeWithTag("placeOrder").assertIsNotEnabled()
        compose.onNodeWithTag("skipAddress").performClick()
        compose.waitUntilExactlyOneExists(hasText("No address. Your haul lands straight in your closet."), slow)
        compose.onNodeWithTag("sheetLeading").performClick()
        compose.waitUntilDoesNotExist(hasTestTag("checkout"), slow)
    }
}

private fun tagPrefix(prefix: String) = SemanticsMatcher("testTag starts with $prefix") {
    it.config.getOrNull(SemanticsProperties.TestTag)?.startsWith(prefix) == true
}
