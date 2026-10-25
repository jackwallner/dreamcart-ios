package com.jackwallner.shop

import android.app.Application
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.shop.data.Analytics
import com.jackwallner.shop.data.ConversionDiagnostics
import com.jackwallner.shop.data.DropReminders
import com.jackwallner.shop.data.ImageLoader
import com.jackwallner.shop.data.PrefsStore
import com.jackwallner.shop.data.ReviewAccess
import com.jackwallner.shop.data.ShopStore
import com.jackwallner.shop.data.StoreService
import com.jackwallner.shop.data.SupabaseClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob

enum class Appearance(val label: String) { LIGHT("Light"), DARK("Dark"), SYSTEM("Auto") }

/** Every shared object, built once per process. */
class AppGraph(context: Context) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val prefs = context.getSharedPreferences("dreamcart", Context.MODE_PRIVATE)
    val supabase = SupabaseClient(context.getSharedPreferences("dreamcart_session", Context.MODE_PRIVATE))
    val analytics = Analytics(supabase, scope, "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})", enabled = !BuildConfig.DEBUG)
    val diagnostics = ConversionDiagnostics(PrefsStore(prefs))
    val store = StoreService(context.applicationContext, diagnostics)
    val reviewAccess = ReviewAccess(PrefsStore(prefs), BuildConfig.PLAY_REVIEW_CODE_SHA256)
    val shop = ShopStore(supabase, prefs, analytics, scope, reviewAccess).apply { onSignedIn = { store.configure(it) } }
    val images = ImageLoader(context)
    val reminders = DropReminders(context.applicationContext, prefs)

    var appearance by mutableStateOf(
        Appearance.entries.firstOrNull { it.name == prefs.getString("appearance", null) } ?: Appearance.LIGHT,
    )
        private set

    /** Debug screenshot mode hides commerce prompts, like `-DreamCartScreenshot`. */
    var screenshotMode by mutableStateOf(false)

    fun updateAppearance(a: Appearance) {
        appearance = a
        prefs.edit().putString("appearance", a.name).apply()
    }
}

class DreamCartApplication : Application() {
    lateinit var graph: AppGraph
        private set

    override fun onCreate() {
        super.onCreate()
        graph = AppGraph(this)
    }
}
