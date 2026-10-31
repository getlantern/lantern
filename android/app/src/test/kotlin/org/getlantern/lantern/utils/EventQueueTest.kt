package org.getlantern.lantern.utils

import org.junit.Assert.assertEquals
import org.junit.Test

class EventQueueTest {
    private val pending = ArrayDeque<Runnable>()
    private val queue = EventQueue<String> { pending.addLast(it) }

    private fun runPending() {
        while (pending.isNotEmpty()) pending.removeFirst().run()
    }

    @Test
    fun deliversEveryEventInOrderWithoutCoalescing() {
        val got = mutableListOf<String>()
        queue.addListener { got.add(it) }
        // Emitted before the main thread runs, as a burst from the core is.
        queue.emit("selection-changed")
        queue.emit("peer-snapshot")
        queue.emit("helper-live")
        queue.emit("peer-snapshot")
        runPending()
        assertEquals(listOf("selection-changed", "peer-snapshot", "helper-live", "peer-snapshot"), got)
    }

    @Test
    fun aRemovedListenerHearsNothingMore() {
        val got = mutableListOf<String>()
        val listener: (String) -> Unit = { got.add(it) }
        queue.addListener(listener)
        queue.emit("a")
        runPending()
        queue.removeListener(listener)
        queue.emit("b")
        runPending()
        assertEquals(listOf("a"), got)
    }

    @Test
    fun noEventIsReplayedToALateListener() {
        queue.emit("before")
        runPending()
        val got = mutableListOf<String>()
        queue.addListener { got.add(it) }
        runPending()
        assertEquals(emptyList<String>(), got)
    }

    @Test
    fun anEventQueuedBeforeAListenerAttachesSkipsIt() {
        val early = mutableListOf<String>()
        queue.addListener { early.add(it) }
        queue.emit("before")
        val late = mutableListOf<String>()
        queue.addListener { late.add(it) }
        runPending()
        assertEquals(listOf("before"), early)
        assertEquals(emptyList<String>(), late)
    }

    @Test
    fun aListenerRemovedBeforeDeliveryHearsNothing() {
        val got = mutableListOf<String>()
        val listener: (String) -> Unit = { got.add(it) }
        queue.addListener(listener)
        queue.emit("queued")
        queue.removeListener(listener)
        runPending()
        assertEquals(emptyList<String>(), got)
    }
}
