package com.jackwallner.shop.data

import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

/** The slice of SharedPreferences the funnel record needs, so JVM tests can use a map. */
interface KeyValueStore {
    fun getInt(key: String): Int
    fun getLong(key: String): Long
    fun getString(key: String): String?
    fun has(key: String): Boolean
    fun putInt(key: String, value: Int)
    fun putLong(key: String, value: Long)
    fun putString(key: String, value: String)
    fun keys(): Set<String>
}

class PrefsStore(private val prefs: SharedPreferences) : KeyValueStore {
    override fun getInt(key: String) = prefs.getInt(key, 0)
    override fun getLong(key: String) = prefs.getLong(key, 0)
    override fun getString(key: String): String? = prefs.getString(key, null)
    override fun has(key: String) = prefs.contains(key)
    override fun putInt(key: String, value: Int) = prefs.edit().putInt(key, value).apply()
    override fun putLong(key: String, value: Long) = prefs.edit().putLong(key, value).apply()
    override fun putString(key: String, value: String) = prefs.edit().putString(key, value).apply()
    override fun keys(): Set<String> = prefs.all.keys
}

/**
 * `ConversionDiagnostics.swift`: the fleet-wide on-device paywall funnel, same
 * keys and the same RevenueCat subscriber attributes as iOS.
 */
class ConversionDiagnostics(private val d: KeyValueStore, private val now: () -> Long = System::currentTimeMillis) {
    fun recordAppOpen() {
        if (!d.has(INSTALLED_AT)) d.putLong(INSTALLED_AT, now())
        d.putInt(APP_OPENS, d.getInt(APP_OPENS) + 1)
    }

    fun recordPitchView(impressionId: String) {
        val surface = surface(impressionId)
        d.putInt(TOTAL_VIEWS, d.getInt(TOTAL_VIEWS) + 1)
        d.putInt(VIEWS_PREFIX + surface, d.getInt(VIEWS_PREFIX + surface) + 1)
        d.putString(LAST_SURFACE, surface)
        if (!d.has(FIRST_SEEN)) {
            d.putLong(FIRST_SEEN, now())
            d.putInt(OPENS_BEFORE_FIRST, d.getInt(APP_OPENS))
            if (d.has(INSTALLED_AT)) d.putInt(DAYS_TO_FIRST, days(d.getLong(INSTALLED_AT)))
        }
    }

    fun recordConversion(plan: String, startedTrial: Boolean) {
        if (d.getString(CONVERTED_ON) != null) return
        d.putString(CONVERTED_ON, d.getString(LAST_SURFACE) ?: "unknown")
        d.putInt(VIEWS_AT_CONVERT, d.getInt(TOTAL_VIEWS))
        d.putString(CONVERTED_PLAN, plan)
        d.putString(CONVERTED_TRIAL, startedTrial.toString())
        d.putLong(CONVERTED_AT, now())
        if (d.has(FIRST_SEEN)) d.putInt(DAYS_TO_CONVERT, days(d.getLong(FIRST_SEEN)))
    }

    val subscriberAttributes: Map<String, String>
        get() {
            val total = d.getInt(TOTAL_VIEWS)
            if (total <= 0) return emptyMap()
            val a = mutableMapOf("pitch_views_total" to total.toString())
            for (key in d.keys()) {
                if (!key.startsWith(VIEWS_PREFIX) || key == TOTAL_VIEWS) continue
                val count = d.getInt(key)
                if (count > 0) a["pitch_views_${key.removePrefix(VIEWS_PREFIX)}".take(40)] = count.toString()
            }
            d.getString(LAST_SURFACE)?.let { a["pitch_last"] = it }
            if (d.has(FIRST_SEEN)) {
                a["pitch_first_seen"] = iso(d.getLong(FIRST_SEEN))
                a["days_since_first_pitch"] = days(d.getLong(FIRST_SEEN)).toString()
            }
            if (d.has(DAYS_TO_FIRST)) a["days_since_install"] = d.getInt(DAYS_TO_FIRST).toString()
            if (d.has(OPENS_BEFORE_FIRST)) a["opens_before_first_pitch"] = d.getInt(OPENS_BEFORE_FIRST).toString()
            d.getString(CONVERTED_ON)?.let { on ->
                a["converted_surface"] = on
                if (d.has(CONVERTED_AT)) a["converted_at"] = iso(d.getLong(CONVERTED_AT))
                a["pitch_views_at_convert"] = d.getInt(VIEWS_AT_CONVERT).toString()
                if (d.has(DAYS_TO_CONVERT)) a["days_to_convert"] = d.getInt(DAYS_TO_CONVERT).toString()
                d.getString(CONVERTED_PLAN)?.let { a["converted_plan"] = it }
                d.getString(CONVERTED_TRIAL)?.let { a["converted_with_trial"] = it }
            }
            return a
        }

    private fun days(since: Long) = maxOf(0, ((now() - since) / 86_400_000L).toInt())

    private fun iso(millis: Long): String = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
        .apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date(millis))

    companion object {
        fun surface(impressionId: String) = impressionId.removePrefix("dreamcart_")
        private const val TOTAL_VIEWS = "conv.pitchViews.total"
        private const val VIEWS_PREFIX = "conv.pitchViews."
        private const val FIRST_SEEN = "conv.pitchFirstSeen"
        private const val LAST_SURFACE = "conv.pitchLastSurface"
        private const val INSTALLED_AT = "conv.installedAt"
        private const val APP_OPENS = "conv.appOpens"
        private const val OPENS_BEFORE_FIRST = "conv.opensBeforeFirstPitch"
        private const val DAYS_TO_FIRST = "conv.daysToFirstPitch"
        private const val CONVERTED_ON = "conv.convertedOn"
        private const val CONVERTED_AT = "conv.convertedAt"
        private const val VIEWS_AT_CONVERT = "conv.viewsAtConvert"
        private const val DAYS_TO_CONVERT = "conv.daysToConvert"
        private const val CONVERTED_PLAN = "conv.convertedPlan"
        private const val CONVERTED_TRIAL = "conv.convertedWithTrial"
    }
}

/**
 * `Analytics.swift`: buffered product events into the same `analytics_events`
 * table, flushed every 30 s or 20 events. Props carry `platform: android`.
 * Debug builds send nothing, so agent and emulator runs never reach the table.
 */
class Analytics(private val client: SupabaseClient, private val scope: CoroutineScope, private val appVersion: String, private val enabled: Boolean) {
    private val sessionId = UUID.randomUUID().toString()
    private val buffer = mutableListOf<JSONObject>()

    init {
        if (enabled) scope.launch {
            while (true) {
                delay(30_000)
                flush()
            }
        }
    }

    fun track(name: String, props: Map<String, Any?> = emptyMap()) {
        if (!enabled) return
        val p = JSONObject()
        props.forEach { (k, v) -> if (v != null) p.put(k, if (v is List<*>) JSONArray(v) else v) }
        p.put("platform", "android")
        val row = JSONObject()
            .put("user_id", client.currentUserId ?: JSONObject.NULL)
            .put("session_id", sessionId)
            .put("name", name)
            .put("props", p)
            .put("client_timestamp", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }.format(Date()))
            .put("app_version", appVersion)
            .put("locale", Locale.getDefault().toString())
        val full = synchronized(buffer) {
            buffer += row
            buffer.size >= 20
        }
        if (full) scope.launch { flush() }
    }

    suspend fun flush() {
        val batch = synchronized(buffer) { buffer.toList().also { buffer.clear() } }
        if (batch.isEmpty()) return
        val uid = client.currentUserId
        if (uid != null) batch.forEach { if (it.isNull("user_id")) it.put("user_id", uid) }
        runCatching { client.insertBestEffort("analytics_events", JSONArray(batch).toString()) }
    }
}
