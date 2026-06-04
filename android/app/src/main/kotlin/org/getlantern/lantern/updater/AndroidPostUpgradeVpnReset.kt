package org.getlantern.lantern.updater

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.getlantern.lantern.service.LanternVpnService
import org.getlantern.lantern.utils.AppLogger

/**
 * Runs one best-effort VPN teardown per package install before Radiance starts.
 * This gives Android a clean VpnService/TUN handoff after in-place APK upgrades.
 */
object AndroidPostUpgradeVpnReset {
    private const val TAG = "PostUpgradeVpnReset"
    private const val PREFS_NAME = "post_upgrade_vpn_reset"
    private const val KEY_LAST_RESET_PACKAGE_INSTALL = "last_reset_package_install"

    suspend fun runIfNeeded(context: Context): Boolean {
        return withContext(Dispatchers.IO) {
            val appContext = context.applicationContext
            val currentPackageInstall = runCatching {
                currentPackageInstall(appContext)
            }.getOrElse { e ->
                AppLogger.e(TAG, "Unable to read package install state; skipping post-upgrade VPN reset", e)
                return@withContext false
            }
            val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val previousPackageInstall = if (prefs.contains(KEY_LAST_RESET_PACKAGE_INSTALL)) {
                prefs.getString(KEY_LAST_RESET_PACKAGE_INSTALL, null)
            } else {
                null
            }

            if (previousPackageInstall == currentPackageInstall) {
                return@withContext false
            }

            val previousLabel = previousPackageInstall ?: "untracked"
            val reason = "package install change previous=$previousLabel current=$currentPackageInstall"
            AppLogger.i(TAG, "Detected first launch for $reason")
            logVpnPrepareState(appContext)

            try {
                LanternVpnService.resetVpnForUpgrade(appContext, reason)
            } finally {
                prefs.edit().putString(KEY_LAST_RESET_PACKAGE_INSTALL, currentPackageInstall).apply()
            }
            true
        }
    }

    private fun logVpnPrepareState(context: Context) {
        runCatching {
            val state = if (VpnService.prepare(context) == null) {
                "prepared"
            } else {
                "permission_required"
            }
            AppLogger.i(TAG, "VpnService.prepare state during post-upgrade reset: $state")
        }.onFailure { e ->
            AppLogger.e(TAG, "Unable to read VpnService.prepare state during post-upgrade reset", e)
        }
    }

    private fun currentPackageInstall(context: Context): String {
        val packageInfo = packageInfo(context)
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            packageInfo.versionCode.toLong()
        }
        return "versionCode=$versionCode lastUpdateTime=${packageInfo.lastUpdateTime}"
    }

    private fun packageInfo(context: Context): PackageInfo {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(context.packageName, 0)
        }
    }
}
