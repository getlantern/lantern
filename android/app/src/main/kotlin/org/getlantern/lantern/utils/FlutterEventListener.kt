package org.getlantern.lantern.utils

import android.util.Log
import lantern.io.utils.FlutterEventEmitter


// Plain Kotlin event carried through the stream. The emitter receives the event
// fields by value as strings (see FlutterEventEmitter.SendEvent), so no gomobile
// Go object ever crosses into the queue.
data class AppEvent(val type: String, val message: String)

/**
 * The core's events on their way to Flutter. Every event is delivered: a
 * coalescing LiveData let a snapshot replace a selection-changed or
 * helper-live event before Flutter saw it.
 */
val FlutterEventStream = EventQueue<AppEvent>()


class FlutterEventListener : FlutterEventEmitter {
    override fun sendEvent(p0: String?, p1: String?) {
        val type = p0.orEmpty()
        val message = p1.orEmpty()
        if (isHighVolume(type)) {
            Log.v(TAG, "Sending Flutter event: $type")
        } else {
            AppLogger.d(TAG, "Sending Flutter event: ${HelperTags.loggableEvent(type, message)}")
        }
        FlutterEventStream.emit(AppEvent(type, message))
    }

    companion object {
        private const val TAG = "FlutterEventListener"

        /**
         * Events too frequent to write to the log file, as iOS and macOS log them
         * only with trace logging on. The snapshots arrive every second while
         * sharing and carry the addresses of the peers relayed, so only their
         * type goes to logcat.
         */
        private val highVolumeEvents = setOf(
            "peer-connection",
            "data-cap-event",
            "unbounded-snapshot",
            "peer-snapshot",
            "user-message-available",
        )

        fun isHighVolume(type: String): Boolean = type in highVolumeEvents
    }
}