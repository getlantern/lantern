package org.getlantern.lantern.utils

import android.app.Activity
import android.content.Context
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import org.getlantern.lantern.BuildConfig
import org.getlantern.lantern.LanternApp


object DeviceUtil {
    fun getLanguageCode(context: Context): String {
        val locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            context.resources.configuration.locales[0]
        } else {
            context.resources.configuration.locale
        }
        val lang = locale.language + "_" + locale.country;
        return lang
    }

    fun devicePlatform(): String {
        return "android"
    }

    fun deviceId(): String? {
        val rawId = Settings.Secure.getString(
            LanternApp.application.contentResolver,
            Settings.Secure.ANDROID_ID
        )
        return if (BuildConfig.DEBUG) {
            // In debug mode, return obfuscated ID
            rawId?.hashCode()?.toUInt()?.toString(16)
        } else {
            // In release mode, return actual ID
            rawId
        }
    }

    fun deviceOs(): String {
        return String.format("Android-%s", Build.VERSION.RELEASE)
    }

    // networkMcc returns the 3-digit Mobile Country Code of the cell
    // tower the device is currently camped on. Empty string when
    // unavailable (WiFi-only device, no signal, no telephony service).
    // No runtime permission is required; networkOperator reflects the
    // tower we're registered with regardless of which SIM is inserted.
    fun networkMcc(context: Context): String {
        return try {
            val tm = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                ?: return ""
            if (tm.phoneType == TelephonyManager.PHONE_TYPE_NONE) return ""
            val op = tm.networkOperator ?: ""
            if (op.length >= 3) op.substring(0, 3) else ""
        } catch (e: Exception) {
            AppLogger.w("DeviceUtil", "Failed to read network MCC: ${e.message}")
            ""
        }
    }

    fun model(): String {
        return Build.MODEL ?: ""
    }

    fun hardware(): String {
        return Build.HARDWARE ?: ""
    }

    fun sdkVersion(): Long {
        return Build.VERSION.SDK_INT.toLong()
    }


    fun isStoreVersion(activity: Activity): Boolean {
        try {
//            if (BuildConfig.PLAY_VERSION) {
//                return true
//            }
            val validInstallers: List<String> = ArrayList(
                listOf(
                    "com.android.vending",
                    "com.google.android.feedback"
                )
            )
            val installer = activity.packageManager
                .getInstallerPackageName(activity.packageName)
            return installer != null && validInstallers.contains(installer)
        } catch (e: java.lang.Exception) {
            AppLogger.e(
                "DeviceUtil",
                "Error checking store version",
                e
            )
        }
        return false
    }


}