package org.getlantern.lantern

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.Process
import androidx.fragment.app.FragmentActivity
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import io.flutter.embedding.android.FlutterFragment
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

private const val CHANNEL = "org.getlantern.lantern.test/public_ip"
private val installed = AtomicBoolean(false)

/**
 * Lets the Dart e2e suite read [PublicIpProbeService] over [CHANNEL], so the
 * suite that drives the VPN through the UI also checks where traffic exits.
 * The handler is attached to each MainActivity engine as it resumes.
 */
internal fun installPublicIpProbeChannel() {
    if (!installed.compareAndSet(false, true)) return
    val context = InstrumentationRegistry.getInstrumentation().targetContext
    val probePackage = InstrumentationRegistry.getInstrumentation().context.packageName
    ActivityLifecycleMonitorRegistry.getInstance().addLifecycleCallback { activity, stage ->
        if (stage != Stage.RESUMED || activity !is FragmentActivity) return@addLifecycleCallback
        val engine = activity.supportFragmentManager.fragments
            .filterIsInstance<FlutterFragment>()
            .firstNotNullOfOrNull { it.flutterEngine } ?: return@addLifecycleCallback
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "probe") return@setMethodCallHandler result.notImplemented()
            thread(name = "public-ip-probe-client") {
                val reply = probePublicIp(context, probePackage)
                Handler(Looper.getMainLooper()).post { result.success(reply) }
            }
        }
    }
}

/** Asks the probe once. Every failure comes back as an `error` entry so the caller can retry. */
internal fun probePublicIp(context: Context, probePackage: String): Map<String, Any?> {
    val received = ArrayBlockingQueue<Bundle>(1)
    // A framework Messenger, not a ResultReceiver subclass: the probe's
    // process can't load this APK's classes to unparcel one.
    val reply = Messenger(Handler(Looper.getMainLooper()) { message ->
        received.offer(Bundle(message.data))
        true
    })
    val connected = ArrayBlockingQueue<Messenger>(1)
    val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            connected.offer(Messenger(binder))
        }

        override fun onServiceDisconnected(name: ComponentName) = Unit
    }
    val intent = Intent().setComponent(ComponentName(probePackage, PublicIpProbeService::class.java.name))
    if (!context.bindService(intent, connection, Context.BIND_AUTO_CREATE)) {
        return mapOf(PublicIpProbeService.ERROR to "Could not bind probe service")
    }
    try {
        val messenger = connected.poll(10, TimeUnit.SECONDS)
            ?: return mapOf(PublicIpProbeService.ERROR to "Probe service did not connect")
        messenger.send(Message.obtain().apply { replyTo = reply })
        val result = received.poll(25, TimeUnit.SECONDS)
            ?: return mapOf(PublicIpProbeService.ERROR to "Probe service did not reply")
        if (result.getInt(PublicIpProbeService.UID) == Process.myUid()) {
            return mapOf(PublicIpProbeService.ERROR to "Probe ran inside Lantern's UID")
        }
        return mapOf(
            PublicIpProbeService.VPN to result.getBoolean(PublicIpProbeService.VPN),
            PublicIpProbeService.IP to result.getString(PublicIpProbeService.IP),
            PublicIpProbeService.ERROR to result.getString(PublicIpProbeService.ERROR),
        )
    } catch (e: Exception) {
        return mapOf(PublicIpProbeService.ERROR to e.toString())
    } finally {
        context.unbindService(connection)
    }
}
