package org.getlantern.lantern.utils

import android.content.Context
import android.net.IpPrefix
import android.os.Build
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