package org.getlantern.lantern.utils

import android.util.Log
import androidx.lifecycle.MutableLiveData
import lantern.io.utils.FlutterEvent
import lantern.io.utils.FlutterEventEmitter


object FlutterEventStream {
    private val _events = MutableLiveData<Event<FlutterEvent>>()
    val events: MutableLiveData<Event<FlutterEvent>> = _events

    fun emit(event: FlutterEvent) {
        _events.postValue(Event(event))
    }
}


class FlutterEventListener : FlutterEventEmitter {
    override fun sendEvent(p0: FlutterEvent?) {
        if (p0 != null) {
            Log.d("FlutterEventListener", "Sending Flutter event: $p0")
            FlutterEventStream.emit(p0)
        }
    }
}