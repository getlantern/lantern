package org.getlantern.lantern.handler

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope

class MethodHandler(private val scope: CoroutineScope) : FlutterPlugin,
    MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null

    companion object {
        const val TAG = "A/MethodHandler"
        const val channelName = "org.getlantern.lantern/method"
    }


    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            binding.binaryMessenger,
            channelName,
        )
        channel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {

    }
}