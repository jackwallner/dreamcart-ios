package com.jackwallner.shop

import android.content.Intent

/** Release builds ignore every launch option, and have no tester sign-in. */
object DebugLaunchOptions {
    @Suppress("UNUSED_PARAMETER")
    fun apply(graph: AppGraph, intent: Intent?) = Unit

    val testerSignInAvailable: Boolean get() = false
}
