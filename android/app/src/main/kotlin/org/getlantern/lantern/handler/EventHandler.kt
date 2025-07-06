package org.getlantern.lantern.handler

import android.util.Log
import androidx.lifecycle.Observer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.JSONMethodCodec
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.utils.Event
import org.getlantern.lantern.utils.PrivateServerEventStream
import org.getlantern.lantern.utils.VpnStatusManager


class EventHandler : FlutterPlugin {

    companion object {
        const val TAG = "A/EventHandler"
        const val SERVICE_STATUS = "org.getlantern.lantern/status"
        const val PRIVATE_SERVER_STATUS = "org.getlantern.lantern/private_server_status"
    }

    private var statusChannel: EventChannel? = null
    private var privateServerStatusChannel: EventChannel? = null

    private var statusObserver: Observer<Event<VPNStatus>>? = null
    var job: Job? = null
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Event handler Attaching to engine")
        statusChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            SERVICE_STATUS,
            JSONMethodCodec.INSTANCE
        )
        privateServerStatusChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            PRIVATE_SERVER_STATUS,
            JSONMethodCodec.INSTANCE
        )

        statusChannelListeners()
        privateServerStatus()

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


    private fun statusChannelListeners() {
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
                if (statusObserver != null) {
                    VpnStatusManager.vpnStatus.removeObserver(statusObserver!!)
                }

            }
        })
    }

    private fun privateServerStatus() {
        privateServerStatusChannel?.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d(TAG, "Private server status channel listening")
                    job = CoroutineScope(Dispatchers.Main).launch {
                        PrivateServerEventStream.events.collect {
                            Log.d(TAG, "Private server event received: $it")
                            events?.success(it)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    Log.d(TAG, "Private server status channel cancelled")
                    job?.cancel()

                }
            },
        )

    }

}