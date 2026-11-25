package org.getlantern.lantern.utils

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.PowerManager
import androidx.core.content.ContextCompat
import lantern.io.mobile.Mobile
import org.getlantern.lantern.LanternApp
import java.util.concurrent.Executor
import java.util.concurrent.Executors

/**
 * Listens for Doze while a tunnel is up and pauses the tunnel's background
 * work, such as server probes, for as long as the device is idle.
 */
object DeviceIdleMonitor {
    private const val TAG = "DeviceIdleMonitor"

    private val forwarder = DeviceIdleForwarder(
        Executors.newSingleThreadExecutor(),
        isIdle = ::isDeviceIdle,
        pause = { Mobile.devicePause() },
        wake = { Mobile.deviceWake() },
        onError = { AppLogger.e(TAG, "Failed to apply device idle state", it) },
    )

    // Only runtime-registered receivers get this broadcast.
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            AppLogger.i(TAG, "Device idle mode changed: idle=${isDeviceIdle()}")
            forwarder.reconcile()
        }
    }
    private var registered = false

    private fun isDeviceIdle(): Boolean = LanternApp.powerManager.isDeviceIdleMode

    /** Call whenever a tunnel comes up: a new tunnel starts awake, even in Doze. */
    @Synchronized
    fun start() {
        if (!registered) {
            ContextCompat.registerReceiver(
                LanternApp.application,
                receiver,
                IntentFilter(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED),
                ContextCompat.RECEIVER_NOT_EXPORTED,
            )
            registered = true
        }
        forwarder.reconcile()
    }

    @Synchronized
    fun stop() {
        if (!registered) return
        registered = false
        runCatching { LanternApp.application.unregisterReceiver(receiver) }
            .onFailure { AppLogger.e(TAG, "Receiver not registered", it) }
    }
}

/**
 * Applies the device's idle state to the tunnel. Calls run in order on
 * [executor], off the main thread: the tunnel's lock can be held for seconds
 * while it connects.
 */
class DeviceIdleForwarder(
    private val executor: Executor,
    private val isIdle: () -> Boolean,
    private val pause: () -> Unit,
    private val wake: () -> Unit,
    private val onError: (Throwable) -> Unit = {},
) {
    /**
     * Applies the device's idle state as of when the task runs, not when it
     * was queued, so a late task cannot undo a newer change. Pause and wake
     * are idempotent, so a redundant one does nothing.
     */
    fun reconcile() {
        executor.execute {
            // An uncaught throw on the executor thread would kill the process.
            runCatching { if (isIdle()) pause() else wake() }.onFailure(onError)
        }
    }
}
