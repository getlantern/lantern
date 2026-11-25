package org.getlantern.lantern.utils

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.concurrent.Executor

class DeviceIdleForwarderTest {
    private var idle = false
    private val calls = mutableListOf<String>()
    private val queued = mutableListOf<Runnable>()
    private val forwarder = DeviceIdleForwarder(
        Executor { queued.add(it) },
        isIdle = { idle },
        pause = { calls.add("pause") },
        wake = { calls.add("wake") },
    )

    private fun runQueued() {
        queued.forEach { it.run() }
        queued.clear()
    }

    @Test
    fun appliesTheIdleStateOffTheCallingThread() {
        idle = true
        forwarder.reconcile()
        assertEquals(emptyList<String>(), calls)
        runQueued()
        assertEquals(listOf("pause"), calls)

        idle = false
        forwarder.reconcile()
        runQueued()
        assertEquals(listOf("pause", "wake"), calls)
    }

    // A tunnel start queued while the device was idle runs after Doze has
    // ended. It must not pause the tunnel the wake just resumed.
    @Test
    fun aLateTaskAppliesTheCurrentStateNotTheQueuedOne() {
        idle = true
        forwarder.reconcile()
        idle = false
        forwarder.reconcile()
        runQueued()
        assertEquals(listOf("wake", "wake"), calls)
    }

    @Test
    fun aThrowingCallIsReportedNotRethrown() {
        val errors = mutableListOf<Throwable>()
        val failure = IllegalStateException("boom")
        val throwing = DeviceIdleForwarder(
            Executor { it.run() },
            isIdle = { true },
            pause = { throw failure },
            wake = {},
            onError = { errors.add(it) },
        )
        throwing.reconcile()
        assertEquals(listOf<Throwable>(failure), errors)
    }
}
