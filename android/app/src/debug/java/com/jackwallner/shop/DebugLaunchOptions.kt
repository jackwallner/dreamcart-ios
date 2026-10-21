package com.jackwallner.shop

import android.content.Intent
import kotlinx.coroutines.launch

/**
 * Debug-only launch extras for tests and screenshots, the Android side of the
 * iOS launch arguments. None of this is compiled into a release build.
 *
 *     adb shell am start -n com.jackwallner.shop/.MainActivity \
 *         --ez onboarded true --ez tester true --es appearance dark
 *
 * `tester` signs in the shared debug tester account (the iOS "Continue as
 * tester" button), `guest` starts guest browsing, `screenshot`
 * (`-DreamCartScreenshot`) hides commerce prompts, and `rcProbe`
 * (`-rcfunnelprobe`) makes the DreamCart+ button buy a Test Store package.
 */
object DebugLaunchOptions {
    fun apply(graph: AppGraph, intent: Intent?) {
        val extras = intent?.extras ?: return
        if (extras.getBoolean("onboarded")) graph.shop.markOnboardedForDebug()
        extras.getString("appearance")?.let { raw ->
            Appearance.entries.firstOrNull { it.name.equals(raw, ignoreCase = true) }?.let(graph::updateAppearance)
        }
        if (extras.getBoolean("screenshot")) {
            graph.screenshotMode = true
            graph.store.suppressImpressions = true
        }
        if (extras.getBoolean("rcProbe")) graph.store.testStoreProbe = true
        when {
            extras.getBoolean("tester") && !graph.supabase.isSignedIn -> graph.scope.launch { graph.shop.devSignIn() }
            extras.getBoolean("guest") && !graph.supabase.isSignedIn -> graph.shop.continueAsGuest()
        }
    }

    val testerSignInAvailable: Boolean get() = true
}
