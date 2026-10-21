package com.jackwallner.shop

import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import com.jackwallner.shop.model.AppRoute
import com.jackwallner.shop.ui.LocalGraph
import com.jackwallner.shop.ui.RootScreen
import com.jackwallner.shop.ui.theme.DreamCartTheme
import kotlinx.coroutines.launch

@OptIn(ExperimentalComposeUiApi::class)
class MainActivity : ComponentActivity() {
    private val graph: AppGraph get() = (application as DreamCartApplication).graph
    private var pendingRoute by mutableStateOf<AppRoute?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) {
            graph.diagnostics.recordAppOpen()
            graph.shop.bootstrap()
            DebugLaunchOptions.apply(graph, intent)
            pendingRoute = AppRoute.parse(intent?.dataString)
        }
        setContent {
            val dark = when (graph.appearance) {
                Appearance.SYSTEM -> isSystemInDarkTheme()
                Appearance.LIGHT -> false
                Appearance.DARK -> true
            }
            LaunchedEffect(dark) {
                val bars = if (dark) SystemBarStyle.dark(Color.TRANSPARENT) else SystemBarStyle.light(Color.TRANSPARENT, Color.TRANSPARENT)
                enableEdgeToEdge(statusBarStyle = bars, navigationBarStyle = bars)
            }
            CompositionLocalProvider(LocalGraph provides graph) {
                DreamCartTheme(dark) {
                    // Test tags double as resource ids so UI Automator and screenshot scripts can find controls.
                    Box(Modifier.semantics { testTagsAsResourceId = true }) {
                        RootScreen(graph, pendingRoute) { pendingRoute = null }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        AppRoute.parse(intent.dataString)?.let { pendingRoute = it }
    }

    override fun onResume() {
        super.onResume()
        // A coin pack bought just before backgrounding may only now be credited.
        if (graph.supabase.isSignedIn) graph.scope.launch { graph.shop.reconcilePurchases() }
        graph.reminders.schedule()
    }

    override fun onStop() {
        super.onStop()
        graph.scope.launch { graph.analytics.flush() }
    }
}
