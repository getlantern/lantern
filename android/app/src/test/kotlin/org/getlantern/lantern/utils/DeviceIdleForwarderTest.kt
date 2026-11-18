package org.getlantern.lantern.utils

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.concurrent.Executor

class DeviceIdleForwarderTest {
    private val calls = mutableListOf<String>()
    private val queued = mutableListOf<Runnable>()
    private val forwarder = DeviceIdleForwarder(
        Executor { queued.add(it) },
        pause = { calls.add("pause") },
        wake = { calls.add("wake") },
    )

    private fun runQueued() {
        queued.forEach { it.run() }
        queued.clear()
    }

    @Test
    fun idleChangesPauseAndWakeInOrder() {
        forwarder.onIdleChanged(true)
        forwarder.onIdleChanged(false)
        forwarder.onIdleChanged(true)
        assertEquals(emptyList<String>(), calls)
        runQueued()
        assertEquals(listOf("pause", "wake", "pause"), calls)
    }

    @Test
    fun aTunnelStartedDuringDozeIsPaused() {
        forwarder.onTunnelStarted(true)
        runQueued()
        assertEquals(listOf("pause"), calls)
    }

    @Test
    fun aTunnelStartedAwakeIsLeftAlone() {
        forwarder.onTunnelStarted(false)
        runQueued()
        assertEquals(emptyList<String>(), calls)
    }
}
