// IconCache.kt
package org.getlantern.lantern.apps

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.getlantern.lantern.utils.AppLogger
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.ConcurrentHashMap
import kotlin.collections.forEach
import kotlin.collections.getOrPut
import kotlin.collections.remove
import kotlin.io.startsWith
import kotlin.io.use
import kotlin.text.replace
import kotlin.text.startsWith
import kotlin.text.toRegex

/**
 * Disk cache for rendered app icons
 */
internal object IconCache {
    private const val TAG = "A/IconCache"
    private const val CACHE_DIR = "app_icons"

    private val locks = ConcurrentHashMap<String, Mutex>()

    private fun cacheDir(ctx: Context): File =
        File(ctx.cacheDir, CACHE_DIR).apply { mkdirs() }

    /**
     * pathFor builds the canonical output file path for the given key
     */
    fun pathFor(
        ctx: Context,
        pkg: String,
        lastUpdate: Long,
        sizePx: Int,
        dpi: Int
    ): File {
        val safe = pkg.replace("[^a-zA-Z0-9._-]".toRegex(), "_")
        val name = "${safe}@${lastUpdate}@${sizePx}@${dpi}.webp"
        return File(cacheDir(ctx), name)
    }

    /**
     * getOrCreate returns absolute path to a cached WebP icon, generating it if missing
     */
    suspend fun getOrCreate(
        ctx: Context,
        pkg: String,
        lastUpdate: Long,
        sizePx: Int,
        dpi: Int
    ): String? = withContext(Dispatchers.IO) {
        val out = pathFor(ctx, pkg, lastUpdate, sizePx, dpi)
        if (out.exists()) return@withContext out.absolutePath

        val key = out.absolutePath
        val lock = locks.getOrPut(key) { Mutex() }

        lock.withLock {
            if (out.exists()) return@withLock out.absolutePath

            runCatching {
                val pm = ctx.packageManager
                val drawable = pm.getApplicationIcon(pkg)
                val bmp = renderIcon(drawable, sizePx)
                writeWebp(out, bmp)
                out.absolutePath
            }.onFailure { e ->
                AppLogger.w(TAG, "Icon generation failed for $pkg", e)
            }.getOrNull()
        }.also {
            if (lock.isLocked.not()) {
                locks.remove(key, lock)
            }
        }
    }

    fun exists(
        ctx: Context,
        pkg: String,
        lastUpdate: Long,
        sizePx: Int,
        dpi: Int
    ): Boolean = pathFor(ctx, pkg, lastUpdate, sizePx, dpi).exists()

    // This is used to delete all app icons for a given package
    suspend fun clearForPackage(ctx: Context, pkg: String) = withContext(Dispatchers.IO) {
        val safe = pkg.replace("[^a-zA-Z0-9._-]".toRegex(), "_")
        cacheDir(ctx).listFiles()?.forEach { f ->
            if (f.name.startsWith("$safe@")) runCatching { f.delete() }
        }
    }

    suspend fun clearAll(ctx: Context) = withContext(Dispatchers.IO) {
        cacheDir(ctx).listFiles()?.forEach { runCatching { it.delete() } }
    }

    private fun renderIcon(drawable: Drawable, size: Int): Bitmap {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && drawable is AdaptiveIconDrawable) {
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val c = Canvas(bmp)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(c)
            return bmp
        }

        val src = if (drawable is BitmapDrawable && drawable.bitmap != null) {
            drawable.bitmap
        } else {
            val w = drawable.intrinsicWidth.coerceAtLeast(1)
            val h = drawable.intrinsicHeight.coerceAtLeast(1)
            val b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val c = Canvas(b)
            drawable.setBounds(0, 0, w, h)
            drawable.draw(c)
            b
        }
        return Bitmap.createScaledBitmap(src, size, size, true)
    }

    private fun writeWebp(file: File, bmp: Bitmap) {
        FileOutputStream(file).use { out ->
            val fmt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
                Bitmap.CompressFormat.WEBP_LOSSLESS
            else
                @Suppress("DEPRECATION") Bitmap.CompressFormat.WEBP
            bmp.compress(fmt, 100, out)
        }
    }
}