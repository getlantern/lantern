package org.getlantern.lantern.apps

import android.content.Context

internal data class AppData(
    val packageName: String,
    val label: String,
    val lastUpdateTime: Long,
    val appPath: String,
    val iconPath: String = ""
) {
    fun hasCachedIcon(ctx: Context, sizePx: Int, dpi: Int): Boolean =
        IconCache.pathFor(ctx, packageName, lastUpdateTime, sizePx, dpi).exists()

    fun withIconPathIfCached(ctx: Context, sizePx: Int, dpi: Int): AppData {
        val f = IconCache.pathFor(ctx, packageName, lastUpdateTime, sizePx, dpi)
        return if (f.exists()) copy(iconPath = f.absolutePath) else this
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "package" to packageName,
        "bundleId" to packageName,
        "label" to label,
        "name" to label,
        "appPath" to appPath,
        "iconPath" to iconPath
    )
}