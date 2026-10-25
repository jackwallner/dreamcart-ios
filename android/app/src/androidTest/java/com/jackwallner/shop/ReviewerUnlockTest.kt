package com.jackwallner.shop

import android.content.Intent
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.longClick
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextClearance
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * The Play reviewer unlock. Pass the throwaway code whose SHA-256 is in
 * local.properties with `-Pandroid.testInstrumentationRunnerArguments.reviewCode=...`.
 */
@OptIn(ExperimentalTestApi::class)
@RunWith(AndroidJUnit4::class)
class ReviewerUnlockTest {
    @get:Rule val compose = createEmptyComposeRule()
    private var scenario: ActivityScenario<MainActivity>? = null
    private val slow = 90_000L

    @After fun close() { scenario?.close() }

    @Test fun longPressOnVersionRejectsAWrongCodeAndUnlocksPlusWithTheRightOne() {
        val code = checkNotNull(InstrumentationRegistry.getArguments().getString("reviewCode")) {
            "Supply the throwaway reviewer code as the reviewCode instrumentation argument."
        }
        val app = InstrumentationRegistry.getInstrumentation().targetContext.applicationContext as DreamCartApplication
        val intent = Intent(app, MainActivity::class.java).putExtra("onboarded", true).putExtra("guest", true)
        scenario = ActivityScenario.launch(intent)
        assertFalse(app.graph.shop.isPlus)

        compose.waitUntilAtLeastOneExists(hasTestTag("tab-PROFILE"), slow)
        compose.onNodeWithTag("tab-PROFILE").performClick()
        compose.waitUntilAtLeastOneExists(hasTestTag("version-row"), slow)
        // Scroll to the very end so the row clears the floating tab bar.
        repeat(4) { compose.onNodeWithTag("profile").performTouchInput { swipeUp() } }
        compose.onNodeWithTag("version-row").performTouchInput { longClick() }
        compose.waitUntilAtLeastOneExists(hasTestTag("reviewer-code"), 5_000)

        compose.onNodeWithTag("reviewer-code").performTextInput("wrong")
        compose.onNodeWithTag("reviewer-unlock").performClick()
        compose.onNodeWithText("That code isn't valid.").assertIsDisplayed()
        assertFalse(app.graph.shop.isPlus)

        compose.onNodeWithTag("reviewer-code").performTextClearance()
        compose.onNodeWithTag("reviewer-code").performTextInput(code)
        compose.onNodeWithTag("reviewer-unlock").performClick()
        compose.waitForIdle()
        assertTrue(app.graph.shop.isPlus)
        assertTrue(compose.onAllNodes(hasTestTag("reviewer-code")).fetchSemanticsNodes().isEmpty())
    }
}
