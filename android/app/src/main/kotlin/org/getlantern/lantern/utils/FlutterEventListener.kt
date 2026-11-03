package org.getlantern.lantern.utils

import android.util.Log
import lantern.io.utils.FlutterEvent
import lantern.io.utils.FlutterEventEmitter


/**
 * The core's events on their way to Flutter. Every event is delivered: a
 * coalescing LiveData let a snapshot replace a selection-changed or
 * helper-live event before Flutter saw it.
 */
val FlutterEventStream = EventQueue<FlutterEvent>()


class FlutterEventListener : FlutterEventEmitter {
    override fun sendEvent(p0: FlutterEvent?) {
        if (p0 != null) {
            if (isHighVolume(p0.type)) {
                Log.v(TAG, "Sending Flutter event: ${p0.type}")
            } else {
                AppLogger.d(TAG, "Sending Flutter event: ${HelperTags.loggableEvent(p0.type, p0.message)}")
            }
            FlutterEventStream.emit(p0)
        }
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
        )

        fun isHighVolume(type: String): Boolean = type in highVolumeEvents
    }
}