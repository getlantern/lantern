package org.getlantern.lantern.utils

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
            AppLogger.d(
                "FlutterEventListener",
                "Sending Flutter event: ${HelperTags.loggableEvent(p0.type, p0.message)}",
            )
            FlutterEventStream.emit(p0)
        }
    }
}