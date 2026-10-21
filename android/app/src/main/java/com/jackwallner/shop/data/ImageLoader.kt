package com.jackwallner.shop.data

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit
import kotlinx.coroutines.withContext

/**
 * Product imagery from Pollinations (`ImageMemoryCache` + `ImageDiskCache` +
 * `ImageDownsampler` on iOS). Uncached requests can 429 under burst load, so
 * downloads are capped at four at a time and retried with backoff; grids show
 * a shimmer until the bitmap lands.
 */
class ImageLoader(context: Context) {
    private val dir = File(context.cacheDir, "products").apply { mkdirs() }
    private val memory = object : LruCache<String, Bitmap>(48 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }
    private val gate = Semaphore(4)

    fun cached(url: String, maxPx: Int): Bitmap? = memory.get(key(url, maxPx))

    suspend fun load(url: String, maxPx: Int): Bitmap? {
        if (url.isBlank()) return null
        val k = key(url, maxPx)
        memory.get(k)?.let { return it }
        return withContext(Dispatchers.IO) {
            val file = File(dir, hash(url))
            if (!file.exists()) {
                var attempt = 0
                while (attempt < 3 && !file.exists()) {
                    val ok = gate.withPermit { download(url, file) }
                    if (!ok) delay(1500L * (attempt + 1))
                    attempt++
                }
            }
            if (!file.exists()) return@withContext null
            decode(file, maxPx)?.also { memory.put(k, it) }
        }
    }

    private fun download(url: String, into: File): Boolean = runCatching {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 15_000
        conn.readTimeout = 60_000
        try {
            if (conn.responseCode !in 200..299) return@runCatching false
            val tmp = File(into.parentFile, into.name + ".part")
            conn.inputStream.use { input -> tmp.outputStream().use { input.copyTo(it) } }
            tmp.renameTo(into)
        } finally {
            conn.disconnect()
        }
    }.getOrDefault(false)

    private fun decode(file: File, maxPx: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        if (bounds.outWidth <= 0) {
            file.delete()
            return null
        }
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= maxPx) sample *= 2
        return BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply { inSampleSize = sample })
    }

    private fun key(url: String, maxPx: Int) = "$maxPx|$url"

    private fun hash(s: String): String =
        MessageDigest.getInstance("SHA-1").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }
}
