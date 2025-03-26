package org.getlantern.lantern.utils

import android.content.Context
import android.net.IpPrefix
import android.os.Build
import androidx.annotation.RequiresApi
import lantern.io.libbox.RoutePrefix
import org.getlantern.lantern.LanternApp
import java.io.File
import java.net.InetAddress
import kotlin.coroutines.Continuation

fun isServiceRunning(context: Context, serviceClass: Class<*>): Boolean {
    val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
    return manager.getRunningServices(Int.MAX_VALUE)
        .any { it.service.className == serviceClass.name }
}

@RequiresApi(Build.VERSION_CODES.TIRAMISU)
fun RoutePrefix.toIpPrefix() = IpPrefix(InetAddress.getByName(address()), prefix())

fun configDirFor(context: Context, suffix: String): String {
    return File(
        context.filesDir,
        ".lantern$suffix"
    ).absolutePath
}

fun initConfigDir(): String {
    val dir = File(LanternApp.application.filesDir, ".lantern")
    if (dir.exists()) {
        return dir.absolutePath
    }
    val success = dir.mkdir()

    if (!success) {
        throw Exception("Failed to create config directory")
    }
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