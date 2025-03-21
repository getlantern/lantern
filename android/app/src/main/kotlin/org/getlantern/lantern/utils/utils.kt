package org.getlantern.lantern.utils

import android.content.Context
import android.net.IpPrefix
import android.os.Build
import androidx.annotation.RequiresApi
import lantern.io.libbox.RoutePrefix
import java.net.InetAddress

fun isServiceRunning(context: Context, serviceClass: Class<*>): Boolean {
    val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
    return manager.getRunningServices(Int.MAX_VALUE).any { it.service.className == serviceClass.name }
}

@RequiresApi(Build.VERSION_CODES.TIRAMISU)
fun RoutePrefix.toIpPrefix() = IpPrefix(InetAddress.getByName(address()), prefix())