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
        loadDefaultExclusions(context)
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
        val packageName = DirectConnectionAppExclusions.normalizePackageName(rawPackageName)
        require(DirectConnectionAppExclusions.isValidPackageName(packageName)) {
            "Invalid package name"
        }

        val defaults = defaultPackageNames()
        val added = stringSet(KEY_USER_ADDED).toMutableSet()
        val removedDefaults = stringSet(KEY_USER_REMOVED_DEFAULTS).toMutableSet()

        if (packageName in defaults) {
            removedDefaults -= packageName
        } else {
            added += packageName
        }

        prefs.edit()
            .putStringSet(KEY_USER_ADDED, added)
            .putStringSet(KEY_USER_REMOVED_DEFAULTS, removedDefaults)
            .apply()
    }

    fun removePackage(rawPackageName: String) {
        val packageName = DirectConnectionAppExclusions.normalizePackageName(rawPackageName)
        require(DirectConnectionAppExclusions.isValidPackageName(packageName)) {
            "Invalid package name"
        }

        val defaults = defaultPackageNames()
        val added = stringSet(KEY_USER_ADDED).toMutableSet()
        val removedDefaults = stringSet(KEY_USER_REMOVED_DEFAULTS).toMutableSet()

        if (packageName in defaults) {
            removedDefaults += packageName
        } else {
            added -= packageName
        }

        prefs.edit()
            .putStringSet(KEY_USER_ADDED, added)
            .putStringSet(KEY_USER_REMOVED_DEFAULTS, removedDefaults)
            .apply()
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

        fun enabled(): Boolean = BuildConfig.STEALTH_DIRECT_CONNECTION_APPS

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
