package org.getlantern.lantern.utils

import android.app.Activity
import android.content.Context
import android.os.Build
import android.provider.Settings
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