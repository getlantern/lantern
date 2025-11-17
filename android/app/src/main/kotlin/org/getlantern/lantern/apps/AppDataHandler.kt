package org.getlantern.lantern.apps

import android.content.*
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.graphics.*
import android.graphics.drawable.AdaptiveIconDrawable
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

internal class AppDataHandler(
    private val appCtx: Context
) : EventChannel.StreamHandler {

    companion object {
        private const val TAG = "AppDataHandler"
        private const val MAX_BATCH = 50
        private const val CACHE_DIR = "app_icons"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var job: Job? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        var sizePx = 96
        var densityDpi = appCtx.resources.displayMetrics.densityDpi

        try {
            if (arguments is Map<*, *>) {
                (arguments["sizePx"] as? Number)?.toInt()?.let { sizePx = it.coerceAtLeast(16) }
                (arguments["densityDpi"] as? Number)?.toInt()?.let { densityDpi = it }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse app stream", e)
        }

        job = packageFlow(sizePx, densityDpi)
            .onEach { payload -> events?.success(payload) }
            .catch { e -> Log.w(TAG, "app_stream flow error", e) }
            .launchIn(scope)
    }

    override fun onCancel(arguments: Any?) {
        job?.cancel()
        job = null
    }

    fun dispose() = onCancel(null)

    /**
     * Cold flow that streams installed app updates to Flutter
     */
    private fun packageFlow(sizePx: Int, dpi: Int) = callbackFlow<Map<String, Any?>> {
        val pm = appCtx.packageManager

        // initial snapshot
        launch(Dispatchers.IO) {
            try {
                val lanternPkg = appCtx.packageName
                val launchables = pm.queryIntentActivities(
                    Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER),
                    PackageManager.MATCH_ALL
                )

                val entries = launchables.mapNotNull { ri ->
                    val pkg = ri.activityInfo?.packageName ?: return@mapNotNull null
                    if (AppFilters.shouldSkip(pkg, lanternPkg)) return@mapNotNull null
                    val label = runCatching { ri.loadLabel(pm).toString() }.getOrDefault(pkg)
                    val lastUpdate = runCatching { pm.getPackageInfoCompat(pkg).lastUpdateTime }.getOrDefault(0L)
                    AppData(pkg, label, lastUpdate, appPath = "")
                }
                    .distinctBy { it.packageName }
                    .sortedBy { it.label.lowercase(Locale.getDefault()) }

                val cached = entries.filter { it.hasCachedIcon(appCtx, sizePx, dpi) }
                val missing = entries - cached.toSet()

                // Send snapshot
                (cached + missing)
                    .map { it.withIconPathIfCached(appCtx, sizePx, dpi) }
                    .chunked(MAX_BATCH)
                    .forEach { batch ->
                        trySend(mapOf(
                            "type" to "snapshot",
                            "items" to batch.map { it.toMap() },
                            "removed" to emptyList<String>()
                        ))
                    }

                // Assemble missing icons; emit iconReady for each whenever they land
                val dispatcher = Dispatchers.IO.limitedParallelism(4)
                coroutineScope {
                    missing.forEach { wire ->
                        launch(dispatcher) {
                            IconCache.getOrCreate(appCtx,
                             wire.packageName, 
                             wire.lastUpdateTime, 
                            sizePx,
                            dpi,
                            )?.let { path ->
                                trySend(mapOf(
                                    "type" to "iconReady",
                                    "items" to listOf(wire.copy(iconPath = path).toMap()),
                                    "removed" to emptyList<String>()
                                ))
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "snapshot build failed", e)
            }
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.data?.scheme != "package") return
                val pkg = intent.data?.schemeSpecificPart ?: return

                when (intent.action) {
                    Intent.ACTION_PACKAGE_REMOVED -> {
                        val replacing = intent.getBooleanExtra(Intent.EXTRA_REPLACING, false)
                        if (!replacing) trySend(mapOf(
                            "type" to "delta",
                            "items" to emptyList<Map<String, Any?>>(),
                            "removed" to listOf(pkg)
                        ))
                    }

                    Intent.ACTION_PACKAGE_ADDED,
                    Intent.ACTION_PACKAGE_CHANGED,
                    Intent.ACTION_PACKAGE_REPLACED -> {
                        launch(Dispatchers.IO) {
                            try {
                                val wire = buildIfLaunchable(pm, pkg) ?: return@launch
                                trySend(mapOf(
                                    "type" to "delta",
                                    "items" to listOf(wire.withIconPathIfCached(appCtx, sizePx, dpi).toMap()),
                                    "removed" to emptyList<String>()
                                ))
                                if (!wire.hasCachedIcon(appCtx, sizePx, dpi)) {
                                    IconCache.getOrCreate(appCtx, pkg, wire.lastUpdateTime, sizePx, dpi)?.let { path ->
                                        trySend(mapOf(
                                            "type" to "iconReady",
                                            "items" to listOf(wire.copy(iconPath = path).toMap()),
                                            "removed" to emptyList<String>()
                                        ))
                                    }
                                }
                            } catch (e: Exception) {
                                Log.w(TAG, "delta emit failed for $pkg", e)
                            }
                        }
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
        }
        ContextCompat.registerReceiver(appCtx, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)

        awaitClose {
            runCatching { appCtx.unregisterReceiver(receiver) }
                .onFailure { e -> Log.w(TAG, "unregister app_stream receiver failed", e) }
        }
    }

    private fun buildIfLaunchable(pm: PackageManager, pkg: String): AppData? {
        if (AppFilters.shouldSkip(pkg, appCtx.packageName)) return null
        val launchIntent = pm.getLaunchIntentForPackage(pkg) ?: return null
        val label = runCatching {
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        }.getOrDefault(pkg)
        val lastUpdate = runCatching { pm.getPackageInfoCompat(pkg).lastUpdateTime }.getOrDefault(0L)
        return AppData(pkg, label, lastUpdate, appPath = "")
    }

    private fun isSystemApp(pm: PackageManager, pkg: String): Boolean = runCatching {
        val ai = pm.getApplicationInfo(pkg, 0)
        (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0 ||
        (ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
    }.getOrDefault(false)

    private fun PackageManager.getPackageInfoCompat(pkg: String): PackageInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        else
            @Suppress("DEPRECATION") getPackageInfo(pkg, 0)
}