package org.getlantern.lantern.handler

import androidx.lifecycle.Observer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.JSONMethodCodec
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import lantern.io.utils.FlutterEvent
import org.getlantern.lantern.apps.AppDataHandler
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.utils.AppLogger
import org.getlantern.lantern.utils.Event
import org.getlantern.lantern.utils.FlutterEventStream
import org.getlantern.lantern.utils.LogTailer
import org.getlantern.lantern.utils.PrivateServerEventStream
import org.getlantern.lantern.utils.VpnStatusManager
import org.getlantern.lantern.utils.logDir
import java.io.File


class EventHandler : FlutterPlugin {

    companion object {
        const val TAG = "A/EventHandler"
        const val SERVICE_STATUS = "org.getlantern.lantern/status"
        const val LOGS = "org.getlantern.lantern/logs"
        const val PRIVATE_SERVER_STATUS = "org.getlantern.lantern/private_server_status"
        const val APP_EVENTS = "org.getlantern.lantern/app_events"
        const val APP_STREAM = "org.getlantern.lantern/app_stream"
    }

    private var statusChannel: EventChannel? = null
    private var privateServerStatusChannel: EventChannel? = null
    private var appEventStatusChannel: EventChannel? = null
    private var appDataChannel: EventChannel? = null
    private var logsChannel: EventChannel? = null
    private var appDataHandler: AppDataHandler? = null

    private var statusObserver: Observer<Event<VPNStatus>>? = null
    private var flutterEventObserver: Observer<Event<FlutterEvent>>? = null
    var job: Job? = null
    private var logsJob: Job? = null
    var logFile: File = File(logDir(), "lantern.log")
    private var logsTailer: LogTailer = LogTailer()
    private val eventScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)


    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        AppLogger.d(TAG, "Event handler Attaching to engine")
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
        appEventStatusChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            APP_EVENTS,
            JSONMethodCodec.INSTANCE
        )
        appDataChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            APP_STREAM,
            JSONMethodCodec.INSTANCE
        )
        logsChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            LOGS
        )
        appDataHandler = AppDataHandler(flutterPluginBinding.applicationContext)
        appDataChannel?.setStreamHandler(appDataHandler)

        statusChannelListeners()
        privateServerStatus()
        appEventStatus()
        logsChannelListeners()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        if (statusChannel != null) {
            statusChannel!!.setStreamHandler(null)
        }
        if (statusObserver != null) {
            VpnStatusManager.vpnStatus.removeObserver(statusObserver!!)
            statusObserver = null
        }
        if (privateServerStatusChannel != null) {
            privateServerStatusChannel!!.setStreamHandler(null)
        }
        if (appEventStatusChannel != null) {
            appEventStatusChannel!!.setStreamHandler(null)
        }
        if (flutterEventObserver != null) {
            FlutterEventStream.events.removeObserver(flutterEventObserver!!)
            flutterEventObserver = null
        }
        logsChannel?.setStreamHandler(null)
        logsJob?.cancel()
        appDataChannel?.setStreamHandler(null)
        appDataHandler?.dispose()
        appDataHandler = null

    }


    private fun statusChannelListeners() {
        statusChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                statusObserver = Observer { event ->
                    event.contentIfNotHandled?.let { status ->
                        when (status) {
                            VPNStatus.Connected,
                            VPNStatus.Connecting,
                            VPNStatus.Disconnecting,
                            VPNStatus.Disconnected,
                            VPNStatus.MissingPermission -> {
                                AppLogger.d(TAG, "Sending VPN Status: $status")
                                val map = mapOf("status" to status.name)
                                events?.success(map)
                            }

                            VPNStatus.Error -> {
                                AppLogger.d(TAG, "Sending VPN Status: $status")
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
                    AppLogger.d(TAG, "Private server status channel listening")
                    job = CoroutineScope(Dispatchers.Main).launch {
                        PrivateServerEventStream.events.collect {
                            AppLogger.d(TAG, "Private server event received: $it")
                            events?.success(it)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    AppLogger.d(TAG, "Private server status channel cancelled")
                    job?.cancel()

                }
            },
        )
    }

    private fun appEventStatus() {
        appEventStatusChannel?.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    AppLogger.d(TAG, "App event status channel listening")
                    // Observe the LiveData
                    flutterEventObserver = Observer { wrappedEvent ->
                        wrappedEvent.contentIfNotHandled?.let { event ->
                            val map = mutableMapOf<String, Any?>()
                            map["type"] = event.type
                            map["message"] = event.message
                            events?.success(map)
                        }
                    }

                    FlutterEventStream.events.observeForever(flutterEventObserver!!)
                }

                override fun onCancel(arguments: Any?) {
                    AppLogger.d(TAG, "App event status channel cancelled")
                    if (flutterEventObserver != null) {
                        FlutterEventStream.events.removeObserver(flutterEventObserver!!)
                    }
                }
            })

    }

    private fun logsChannelListeners() {
        logsChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                logsJob = eventScope.launch {
                    // Send initial batch of last 200 lines, matching iOS/macOS behaviour
                    val initial = logsTailer.tail(logFile, 200)
                    if (initial.isNotEmpty()) {
                        withContext(Dispatchers.Main) { events?.success(initial) }
                    }

                    // Track offset so we only send NEW lines on each poll (delta, not snapshot)
                    var fileOffset = logFile.length()

                    while (isActive) {
                        delay(1000)
                        val currentSize = logFile.length()
                        if (currentSize < fileOffset) {
                            // File was rotated or truncated — reset
                            fileOffset = 0
                        }
                        if (currentSize > fileOffset) {
                            val newLines = readLinesSinceOffset(logFile, fileOffset)
                            fileOffset = currentSize
                            if (newLines.isNotEmpty()) {
                                withContext(Dispatchers.Main) { events?.success(newLines) }
                            }
                        }
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                logsJob?.cancel()
            }
        })
    }

    private fun readLinesSinceOffset(file: File, offset: Long): List<String> {
        if (!file.exists() || offset < 0 || file.length() <= offset) return emptyList()
        return try {
            java.io.RandomAccessFile(file, "r").use { raf ->
                raf.seek(offset)
                val lines = mutableListOf<String>()
                java.io.BufferedReader(
                    java.io.InputStreamReader(
                        java.nio.channels.Channels.newInputStream(raf.channel),
                        Charsets.UTF_8,
                    )
                ).use { reader ->
                    var line = reader.readLine()
                    while (line != null) {
                        val trimmed = line.trimEnd('\r')
                        if (trimmed.isNotEmpty()) lines.add(trimmed)
                        line = reader.readLine()
                    }
                }
                lines
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error reading new log lines: ${e.message}")
            emptyList()
        }
    }
}