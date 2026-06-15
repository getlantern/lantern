package org.getlantern.lantern.utils

import androidx.lifecycle.MutableLiveData
import lantern.io.utils.FlutterEventEmitter


// Plain Kotlin event carried through the stream. The emitter receives the event
// fields by value as strings (see FlutterEventEmitter.SendEvent), so no gomobile
// Go object ever crosses into the LiveData stream.
data class AppEvent(val type: String, val message: String)

object FlutterEventStream {
    private val _events = MutableLiveData<Event<AppEvent>>()
    val events: MutableLiveData<Event<AppEvent>> = _events

    fun emit(event: AppEvent) {
        _events.postValue(Event(event))
    }
}


class FlutterEventListener : FlutterEventEmitter {
    override fun sendEvent(p0: String?, p1: String?) {
        AppLogger.d("FlutterEventListener", "Sending Flutter event: $p0")
        FlutterEventStream.emit(AppEvent(p0.orEmpty(), p1.orEmpty()))
    }
}