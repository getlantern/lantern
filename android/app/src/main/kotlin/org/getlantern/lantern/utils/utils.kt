package org.getlantern.lantern.utils

import android.app.AppOpsManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.IpPrefix
import android.os.Build
import android.os.Process
import androidx.annotation.RequiresApi
import lantern.io.libbox.RoutePrefix
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.service.LanternVpnService
import java.io.File
import java.net.InetAddress
import kotlin.coroutines.Continuation

fun isServiceRunning(context: Context, serviceClass: Class<*>): Boolean {
    val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
    return manager.getRunningServices(Int.MAX_VALUE)
        .any { it.service.className == serviceClass.name }
}

fun isVPNRunning(context: Context): Boolean {
    return isServiceRunning(context, LanternVpnService::class.java)
}

// Added in Android 17 (API 37); not in the SDK we compile against.
private const val ACCESS_LOCAL_NETWORK = "android.permission.ACCESS_LOCAL_NETWORK"
private const val LOCAL_NETWORK_PERMISSION_SDK = 37

/**
 * Whether the tunnel may use local addresses. Android 17 gates them behind
 * ACCESS_LOCAL_NETWORK ("Nearby devices"); without it the TUN's own
 * private address is unreachable and no app traffic gets through.
 */
fun hasLocalNetworkAccess(context: Context): Boolean {
    if (Build.VERSION.SDK_INT < LOCAL_NETWORK_PERMISSION_SDK) return true
    if (context.checkSelfPermission(ACCESS_LOCAL_NETWORK) != PackageManager.PERMISSION_GRANTED) {
        return false
    }
    // Apps targeting below 37 keep the permission; denying flips the app op.
    val op = AppOpsManager.permissionToOp(ACCESS_LOCAL_NETWORK) ?: return true
    val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
    val mode = appOps.unsafeCheckOpNoThrow(op, Process.myUid(), context.packageName)
    return mode == AppOpsManager.MODE_ALLOWED
}

@RequiresApi(Build.VERSION_CODES.TIRAMISU)
fun RoutePrefix.toIpPrefix() = IpPrefix(InetAddress.getByName(address()), prefix())


fun setupDirs() {
    initConfigDir()
    logDir()
}

fun initConfigDir(): String {
    val dir = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        File(LanternApp.application.dataDir, ".lantern")
    } else {
        File(LanternApp.application.filesDir, ".lantern")
    }

    if (dir.exists()) {
        return dir.absolutePath
    }
    val success = dir.mkdir()
    if (!success) {
        throw Exception("Failed to create config directory")
    }
    AppLogger.d("Paths", "Created config directory ${dir.absolutePath}")
    return dir.absolutePath
}

fun logDir(): String {
    val dir = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        File(LanternApp.application.dataDir, ".lantern/logs")
    } else {
        File(LanternApp.application.filesDir, ".lantern/logs")
    }

    if (dir.exists()) {
        return dir.absolutePath
    }
    val success = dir.mkdir()
    if (!success) {
        throw Exception("Failed to create logs directory")
    }
    AppLogger.d("Paths", "Created config directory ${dir.absolutePath}")
    return dir.absolutePath
}

fun isTelemetryEnabled(): Boolean {
    val telemetryConsentFile = File(initConfigDir(),".telemetry_enabled")
    return  telemetryConsentFile.exists()
}

fun getRadianceEnv(): String {
    val envFile = File(initConfigDir(), ".radiance_env")
    return try {
        if (envFile.exists()) "stage" else "prod"
    } catch (e: Exception) {
        "prod"
    }
}


fun <T> Continuation<T>.tryResume(value: T) {
    try {
        resumeWith(Result.success(value))
    } catch (ignored: IllegalStateException) {
    }
}

fun <T> Continuation<T>.tryResumeWithException(exception: Throwable) {
    try {
        resumeWith(Result.failure(exception))
    } catch (ignored: IllegalStateException) {
    }
}