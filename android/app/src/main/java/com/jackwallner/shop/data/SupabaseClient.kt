package com.jackwallner.shop.data

import android.content.SharedPreferences
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject

// Publishable, client-safe values, identical to iOS Shared/Services/Config.swift.
// Row level security is the boundary; never put a service-role key here.
object Config {
    const val SUPABASE_URL = "https://wpjmshibfhdpzvfrjzrv.supabase.co"
    const val SUPABASE_PUBLISHABLE_KEY = "sb_publishable_obm-_XQQoXyUjYCm6MLh6w_6nBu1gBu"
    const val PRIVACY_URL = "https://jackwallner.github.io/dreamcart/privacy-policy.html"
    const val TERMS_URL = "https://jackwallner.github.io/dreamcart/terms.html"
    const val SUPPORT_EMAIL = "jackwallner+q@gmail.com"
    const val PLAY_LISTING = "https://play.google.com/store/apps/details?id=com.jackwallner.shop"

    const val REST = "$SUPABASE_URL/rest/v1"
    const val AUTH = "$SUPABASE_URL/auth/v1"
    const val FUNCTIONS = "$SUPABASE_URL/functions/v1"
}

sealed class SupabaseError(message: String) : IOException(message) {
    class Http(val code: Int, val body: String) : SupabaseError("Server error $code: $body")
    object NotAuthenticated : SupabaseError("Please sign in.")
}

data class Session(val accessToken: String, val refreshToken: String, val expiresAtMillis: Long, val userId: String)

/**
 * Minimal Supabase client over HttpURLConnection, the Android twin of the iOS
 * actor: id_token exchange, session persistence and refresh, and authenticated
 * REST, RPC and Edge Function calls. Same project, same RLS as iOS.
 */
class SupabaseClient(private val prefs: SharedPreferences) {
    private val lock = Mutex()
    @Volatile private var session: Session? = null

    init { restore() }

    val isSignedIn: Boolean get() = session != null
    val currentUserId: String? get() = session?.userId

    private fun restore() {
        val access = prefs.getString("access", null) ?: return
        session = Session(
            accessToken = access,
            refreshToken = prefs.getString("refresh", "") ?: "",
            expiresAtMillis = prefs.getLong("expires", 0),
            userId = prefs.getString("user", "") ?: "",
        )
    }

    private fun persist(s: Session) {
        prefs.edit().putString("access", s.accessToken).putString("refresh", s.refreshToken)
            .putLong("expires", s.expiresAtMillis).putString("user", s.userId).apply()
    }

    fun signOutLocal() {
        session = null
        prefs.edit().clear().apply()
    }

    /** Exchange a provider id_token (Google on Android, Apple on iOS) for a Supabase session. */
    suspend fun signInWithIdToken(provider: String, idToken: String, rawNonce: String?) {
        val body = JSONObject().put("provider", provider).put("id_token", idToken)
        if (rawNonce != null) body.put("nonce", rawNonce)
        storeSession(request("${Config.AUTH}/token?grant_type=id_token", "POST", body.toString(), bearer = null))
    }

    /** Email/password sign-in for the debug tester account only. Release UI never reaches it. */
    suspend fun signInWithPassword(email: String, password: String) {
        val body = JSONObject().put("email", email).put("password", password)
        storeSession(request("${Config.AUTH}/token?grant_type=password", "POST", body.toString(), bearer = null))
    }

    private fun storeSession(raw: String) {
        val o = JSONObject(raw)
        val s = Session(
            accessToken = o.getString("access_token"),
            refreshToken = o.getString("refresh_token"),
            expiresAtMillis = System.currentTimeMillis() + o.optLong("expires_in", 3600) * 1000,
            userId = o.getJSONObject("user").getString("id"),
        )
        session = s
        persist(s)
    }

    suspend fun accessToken(): String = lock.withLock {
        val s = session ?: throw SupabaseError.NotAuthenticated
        if (s.expiresAtMillis - System.currentTimeMillis() > 120_000) return@withLock s.accessToken
        try {
            val body = JSONObject().put("refresh_token", s.refreshToken).toString()
            storeSession(request("${Config.AUTH}/token?grant_type=refresh_token", "POST", body, bearer = null))
        } catch (e: SupabaseError.Http) {
            // Refresh token dead: force re-auth.
            signOutLocal()
            throw SupabaseError.NotAuthenticated
        }
        session?.accessToken ?: throw SupabaseError.NotAuthenticated
    }

    private suspend fun bearer(authed: Boolean): String =
        if (authed) runCatching { accessToken() }.getOrNull() ?: Config.SUPABASE_PUBLISHABLE_KEY
        else Config.SUPABASE_PUBLISHABLE_KEY

    /** GET rows with a raw PostgREST query, e.g. `products?select=*,brands(*)`. */
    suspend fun select(path: String, authed: Boolean = true): String =
        request("${Config.REST}/$path", "GET", null, bearer(authed))

    suspend fun rpc(fn: String, args: JSONObject = JSONObject()): String =
        request("${Config.REST}/rpc/$fn", "POST", args.toString(), accessToken())

    suspend fun write(path: String, method: String, body: String?): String =
        request("${Config.REST}/$path", method, body, accessToken(), prefer = "return=representation")

    /** Best-effort telemetry insert that works with or without a session, like iOS. */
    suspend fun insertBestEffort(path: String, body: String) {
        request("${Config.REST}/$path", "POST", body, bearer(true))
    }

    suspend fun callFunction(name: String, body: JSONObject = JSONObject(), timeoutMs: Int = 60_000): String =
        request("${Config.FUNCTIONS}/$name", "POST", body.toString(), accessToken(), timeoutMs = timeoutMs)

    private suspend fun request(
        url: String,
        method: String,
        body: String?,
        bearer: String?,
        prefer: String? = null,
        timeoutMs: Int = 30_000,
    ): String = withContext(Dispatchers.IO) {
        val conn = URL(url).openConnection() as HttpURLConnection
        try {
            conn.requestMethod = method
            conn.connectTimeout = 15_000
            conn.readTimeout = timeoutMs
            conn.setRequestProperty("apikey", Config.SUPABASE_PUBLISHABLE_KEY)
            conn.setRequestProperty("Authorization", "Bearer ${bearer ?: Config.SUPABASE_PUBLISHABLE_KEY}")
            prefer?.let { conn.setRequestProperty("Prefer", it) }
            if (body != null) {
                conn.doOutput = true
                conn.setRequestProperty("content-type", "application/json")
                conn.outputStream.use { it.write(body.toByteArray()) }
            }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.bufferedReader()?.use { it.readText() } ?: ""
            if (code !in 200..299) throw SupabaseError.Http(code, text)
            text
        } finally {
            conn.disconnect()
        }
    }
}
