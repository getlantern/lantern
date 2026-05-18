package org.getlantern.lantern.stealth

import android.content.Context
import android.content.pm.PackageManager
import android.net.VpnService
import org.getlantern.lantern.BuildConfig
import org.getlantern.lantern.utils.AppLogger
import org.json.JSONArray

class DirectConnectionAppExclusionStore(
    private val context: Context,
) {
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val defaultExclusions: List<DirectConnectionAppExclusion> by lazy {
        cachedDefaultExclusions(context.applicationContext)
    }

    fun defaultPackageNames(): Set<String> {
        return defaultExclusions.mapTo(LinkedHashSet()) { it.packageName }
    }

    fun effectivePackageNames(): Set<String> {
        return DirectConnectionAppExclusions.effectivePackageNames(
            defaultPackages = defaultPackageNames(),
            userAddedPackages = stringSet(KEY_USER_ADDED),
            userRemovedDefaultPackages = stringSet(KEY_USER_REMOVED_DEFAULTS),
        )
    }

    fun effectivePackageNamesJson(): String {
        return JSONArray(effectivePackageNames()).toString()
    }

    fun addPackage(rawPackageName: String) {
        updatePackages(listOf(rawPackageName), adding = true)
    }

    fun addPackages(rawPackageNames: Iterable<String>) {
        updatePackages(rawPackageNames, adding = true)
    }

    fun removePackage(rawPackageName: String) {
        updatePackages(listOf(rawPackageName), adding = false)
    }

    fun removePackages(rawPackageNames: Iterable<String>) {
        updatePackages(rawPackageNames, adding = false)
    }

    private fun updatePackages(rawPackageNames: Iterable<String>, adding: Boolean) {
        val packageNames = rawPackageNames.map(::requirePackageName)
        if (packageNames.isEmpty()) {
            return
        }
        val defaults = defaultPackageNames()
        val added = stringSet(KEY_USER_ADDED).toMutableSet()
        val removedDefaults = stringSet(KEY_USER_REMOVED_DEFAULTS).toMutableSet()

        for (packageName in packageNames) {
            if (adding) {
                if (packageName in defaults) {
                    removedDefaults -= packageName
                } else {
                    added += packageName
                }
            } else {
                if (packageName in defaults) {
                    removedDefaults += packageName
                } else {
                    added -= packageName
                }
            }
        }

        prefs.edit()
            .putStringSet(KEY_USER_ADDED, added)
            .putStringSet(KEY_USER_REMOVED_DEFAULTS, removedDefaults)
            .apply()
    }

    private fun requirePackageName(rawPackageName: String): String {
        val packageName = DirectConnectionAppExclusions.normalizePackageName(rawPackageName)
        require(DirectConnectionAppExclusions.isValidPackageName(packageName)) {
            "Invalid package name: raw='$rawPackageName', normalized='$packageName'"
        }
        return packageName
    }

    private fun stringSet(key: String): Set<String> {
        return prefs.getStringSet(key, emptySet()).orEmpty()
            .map(DirectConnectionAppExclusions::normalizePackageName)
            .filter(DirectConnectionAppExclusions::isValidPackageName)
            .toSet()
    }

    companion object {
        private const val TAG = "DirectAppExclusions"
        private const val PREFS_NAME = "direct_connection_app_exclusions"
        private const val KEY_USER_ADDED = "user_added_packages"
        private const val KEY_USER_REMOVED_DEFAULTS = "user_removed_default_packages"

        private val assetCandidates = listOf(
            DirectConnectionAppExclusions.DEFAULT_ASSET_PATH,
            "assets/stealth/default_exclusions.json",
            "stealth/default_exclusions.json",
        )
        @Volatile
        private var defaultExclusionsCache: List<DirectConnectionAppExclusion>? = null

        fun enabled(): Boolean = BuildConfig.STEALTH_DIRECT_CONNECTION_APPS

        private fun cachedDefaultExclusions(
            context: Context,
        ): List<DirectConnectionAppExclusion> {
            defaultExclusionsCache?.let { return it }
            return synchronized(this) {
                defaultExclusionsCache ?: loadDefaultExclusions(context).also {
                    defaultExclusionsCache = it
                }
            }
        }

        fun loadDefaultExclusions(context: Context): List<DirectConnectionAppExclusion> {
            for (path in assetCandidates) {
                val json = runCatching {
                    context.assets.open(path).bufferedReader().use { it.readText() }
                }.getOrNull()

                if (json.isNullOrBlank()) {
                    continue
                }

                val parsed = runCatching {
                    DirectConnectionAppExclusions.parseDefaults(json)
                }.onFailure { e ->
                    AppLogger.w(TAG, "Failed to parse $path", e)
                }.getOrNull()
                if (parsed != null) {
                    return parsed
                }
            }

            AppLogger.w(TAG, "No default direct-connection app exclusions asset found")
            return emptyList()
        }

        fun applyToBuilder(
            builder: VpnService.Builder,
            context: Context,
        ): Int {
            if (!enabled()) {
                return 0
            }

            var applied = 0
            val packages = DirectConnectionAppExclusionStore(context).effectivePackageNames()
            for (packageName in packages) {
                try {
                    builder.addDisallowedApplication(packageName)
                    applied += 1
                } catch (e: PackageManager.NameNotFoundException) {
                    AppLogger.d(TAG, "Skipping direct-connection app not installed: $packageName")
                } catch (e: Exception) {
                    AppLogger.w(TAG, "Skipping direct-connection app: $packageName", e)
                }
            }

            AppLogger.i(
                TAG,
                "Applied $applied direct-connection app exclusions (${packages.size} configured)"
            )
            return applied
        }
    }
}
