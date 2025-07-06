package org.getlantern.lantern.utils

import android.util.Log
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import lantern.io.utils.PrivateServerEventListener
import org.json.JSONObject

object PrivateServerEventStream {
    private val _events = MutableSharedFlow<String>(replay = 1)
    val events: SharedFlow<String> = _events
    fun emit(event: String) {
        _events.tryEmit(event)
    }
}


class PrivateServerListener : PrivateServerEventListener {
    override fun openBrowser(p0: String?) {
        Log.d("PrivateServerListener", "Opening browser with URL: $p0")
        val json = JSONObject(mapOf("status" to "openBrowser", "data" to p0)).toString()
        PrivateServerEventStream.emit(json)
    }

    override fun onPrivateServerEvent(p0: String?) {
        Log.d("PrivateServerListener", "Private server event: $p0")
        PrivateServerEventStream.emit(p0 ?: "")
    }

    override fun onError(p0: String?) {
        PrivateServerEventStream.emit(p0 ?: "")
    }

}