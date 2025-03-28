package org.getlantern.lantern.handler

import android.os.Build
import android.util.Log
import androidx.lifecycle.Observer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.JSONMethodCodec
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.service.QuickTileService
import org.getlantern.lantern.utils.Event
import org.getlantern.lantern.utils.VpnStatusManager


class EventHandler : FlutterPlugin {

    companion object {
        const val TAG = "A/EventHandler"
        const val SERVICE_STATUS = "org.getlantern.lantern/status"
    }

    private var statusChannel: EventChannel? = null

    private var statusObserver: Observer<Event<VPNStatus>>? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Event handler Attaching to engine")
        statusChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            SERVICE_STATUS,
            JSONMethodCodec.INSTANCE
        )

        statusChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                statusObserver = Observer { event ->
                    event.contentIfNotHandled?.let { status ->
                        Log.d(TAG, "Observer VPN Status: $status")
                        when (status) {
                            VPNStatus.Connected,
                            VPNStatus.Connecting,
                            VPNStatus.Disconnecting,
                            VPNStatus.Disconnected,
                            VPNStatus.MissingPermission -> {
                                Log.d(TAG, "Sending VPN Status: $status")
                                val map = mapOf("status" to status.name)
                                events?.success(map)
                            }

                            VPNStatus.Error -> {
                                val map = mapOf(
                                    "status" to status.name,
                                    "error" to status.errorMessage,
                                    "errorCode" to status.errorCode
                                )
                                events?.success(map)
                            }
                        }
                    }
                }
                VpnStatusManager.vpnStatus.observeForever(statusObserver!!)
            }

            override fun onCancel(arguments: Any?) {
                if (statusObserver != null){
                    VpnStatusManager.vpnStatus.removeObserver(statusObserver!!)
                }

            }
        })

    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (statusChannel != null) {
            statusChannel!!.setStreamHandler(null)
        }
        if (statusObserver != null) {
            VpnStatusManager.vpnStatus.removeObserver(statusObserver!!)
            statusObserver = null
        }
    }
}