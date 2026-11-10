package org.getlantern.lantern.service

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.CoroutineContext
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnStartGateTest {
    @Test(timeout = 10_000)
    fun duplicatesCannotEnterPreparation() = runBlocking {
        val gate = VpnStartGate()
        val prepared = CompletableDeferred<Unit>()
        val finish = CompletableDeferred<Unit>()
        val starts = AtomicInteger()
        val first = async {
            gate.run {
                starts.incrementAndGet()
                prepared.complete(Unit)
                finish.await()
            }
        }
        prepared.await()

        val duplicates = List(16) {
            async(Dispatchers.Default) { gate.run { starts.incrementAndGet() } }
        }.awaitAll()
        assertTrue(duplicates.none { it })
        assertEquals(1, starts.get())

        finish.complete(Unit)
        assertTrue(first.await())
        assertTrue(gate.run {})
    }

    @Test
    fun preparationFailureAllowsRetry() = runBlocking {
        val gate = VpnStartGate()
        val failure = IllegalStateException("setup failed")

        val result = runCatching { gate.run { throw failure } }

        assertEquals(failure.javaClass, result.exceptionOrNull()?.javaClass)
        assertEquals(failure.message, result.exceptionOrNull()?.message)
        assertTrue(gate.run {})
    }

    @Test(timeout = 10_000)
    fun foregroundCallbackFailureDoesNotLeakRestartGate() = runBlocking {
        val gate = VpnStartGate()
        val failure = IllegalStateException("foreground promotion failed")

        val result = runCatching {
            gate.run(waitForIdle = true, onRequest = { throw failure }) {
                error("failed promotion must not enter startup")
            }
        }

        assertEquals(failure.message, result.exceptionOrNull()?.message)
        assertTrue(gate.run {})
    }

    @Test
    fun returningWithoutConnectingAllowsRetry() = runBlocking {
        val gate = VpnStartGate()

        assertTrue(gate.run { return@run })
        assertTrue(gate.run {})
    }

    @Test(timeout = 10_000)
    fun cancellingPreparationAllowsRetry() = runBlocking {
        val gate = VpnStartGate()
        val first = launch(start = CoroutineStart.UNDISPATCHED) {
            gate.run { CompletableDeferred<Unit>().await() }
        }

        first.cancelAndJoin()

        assertTrue(gate.run {})
    }

    @Test(timeout = 10_000)
    fun connectFailureAllowsRetry() = runBlocking {
        val gate = VpnStartGate()
        val failure = IllegalStateException("native start failed")

        val result = runCatching {
            gate.run { attempt -> attempt.connect(5_000) { throw failure } }
        }

        assertEquals(failure.javaClass, result.exceptionOrNull()?.javaClass)
        assertEquals(failure.message, result.exceptionOrNull()?.message)
        assertTrue(gate.run {})
    }

    @Test(timeout = 10_000)
    fun completedConnectDoesNotReleaseGateBeforeCleanup() = runBlocking {
        val gate = VpnStartGate()
        val cleaningUp = CompletableDeferred<Unit>()
        val finishCleanup = CompletableDeferred<Unit>()
        val first = launch {
            gate.run { attempt ->
                attempt.connect(5_000) {}
                cleaningUp.complete(Unit)
                finishCleanup.await()
            }
        }
        cleaningUp.await()

        assertFalse(gate.run { error("cleanup is still running") })

        finishCleanup.complete(Unit)
        first.join()
        assertTrue(gate.run {})
    }

    @Test(timeout = 10_000)
    fun timeoutReportsWhileConnectRunsAndLateSuccessIsObserved() = runBlocking {
        val gate = VpnStartGate()
        val entered = CompletableDeferred<Unit>()
        val timedOut = CompletableDeferred<Unit>()
        val release = CountDownLatch(1)
        val events = mutableListOf<String>()
        try {
            val first = async {
                gate.run { attempt ->
                    attempt.connect(200, onTimeout = {
                        events += "timeout"
                        timedOut.complete(Unit)
                    }) {
                        entered.complete(Unit)
                        assertTrue(release.await(5, TimeUnit.SECONDS))
                    }
                    attempt.publish { events += "connected" }
                }
            }
            entered.await()
            timedOut.await()
            assertFalse(first.isCompleted)
            assertFalse(gate.run { error("native connect is still running") })
            release.countDown()
            assertTrue(first.await())
            assertEquals(listOf("timeout", "connected"), events)
            assertTrue(gate.run {})
        } finally {
            release.countDown()
        }
    }

    @Test(timeout = 10_000)
    fun lateFailureFinishesCleanupBeforeAnotherStart() = runBlocking {
        val gate = VpnStartGate()
        val releaseConnect = CountDownLatch(1)
        val entered = CompletableDeferred<Unit>()
        val timedOut = CompletableDeferred<Unit>()
        val cleaningUp = CompletableDeferred<Unit>()
        val finishCleanup = CompletableDeferred<Unit>()
        val failure = IllegalStateException("late native failure")
        try {
            val first = async {
                gate.run { attempt ->
                    val result = runCatching {
                        attempt.connect(200, onTimeout = { timedOut.complete(Unit) }) {
                            entered.complete(Unit)
                            assertTrue(releaseConnect.await(5, TimeUnit.SECONDS))
                            throw failure
                        }
                    }
                    assertEquals(failure.message, result.exceptionOrNull()?.message)
                    cleaningUp.complete(Unit)
                    finishCleanup.await()
                }
            }
            entered.await()
            timedOut.await()
            assertFalse(gate.run { error("timed-out native call is still running") })
            releaseConnect.countDown()
            cleaningUp.await()

            assertFalse(gate.run { error("cleanup is still running after native completion") })

            finishCleanup.complete(Unit)
            assertTrue(first.await())
            assertTrue(gate.run {})
        } finally {
            releaseConnect.countDown()
            finishCleanup.complete(Unit)
        }
    }

    @Test(timeout = 10_000)
    fun cancellationKeepsGateUntilBlockingConnectReturns() = runBlocking {
        val gate = VpnStartGate()
        val entered = CompletableDeferred<Unit>()
        val release = CountDownLatch(1)
        try {
            val first = launch {
                gate.run { attempt ->
                    attempt.connect(5_000) {
                        entered.complete(Unit)
                        assertTrue(release.await(5, TimeUnit.SECONDS))
                    }
                }
            }
            entered.await()
            first.cancel()

            assertFalse(gate.run { error("native connect is still running") })
            assertFalse(first.isCompleted)
            release.countDown()
            first.join()
            assertTrue(gate.run {})
        } finally {
            release.countDown()
        }
    }

    @Test(timeout = 10_000)
    fun cancellationBeforeConnectStartsDoesNotLeakGate() = runBlocking {
        val dispatcher = QueuedDispatcher()
        val gate = VpnStartGate(dispatcher)
        var connected = false
        val first = launch(start = CoroutineStart.UNDISPATCHED) {
            gate.run { attempt -> attempt.connect(5_000) { connected = true } }
        }

        first.cancel()
        dispatcher.runQueued()
        first.join()

        assertFalse(connected)
        assertTrue(gate.run {})
    }

    @Test(timeout = 10_000)
    fun stopCancelsPreparationAndWaitsForCleanup() = runBlocking {
        val gate = VpnStartGate()
        val prepared = CompletableDeferred<Unit>()
        val cleaningUp = CompletableDeferred<Unit>()
        val finishCleanup = CompletableDeferred<Unit>()
        val stopping = CompletableDeferred<Unit>()
        var stopped = false
        val first = launch {
            gate.run {
                try {
                    prepared.complete(Unit)
                    CompletableDeferred<Unit>().await()
                    error("cancelled preparation must not start JNI")
                } finally {
                    withContext(NonCancellable) {
                        cleaningUp.complete(Unit)
                        finishCleanup.await()
                    }
                }
            }
        }
        prepared.await()
        val stop = launch {
            gate.stop(onStopping = { stopping.complete(Unit) }) { stopped = true }
        }
        stopping.await()
        cleaningUp.await()
        assertFalse(stopped)
        assertFalse(gate.run { error("stop is waiting for cleanup") })

        finishCleanup.complete(Unit)
        first.join()
        stop.join()
        assertTrue(stopped)
        assertTrue(gate.run {})
    }

    @Test(timeout = 10_000)
    fun stopWaitsForNativeCompletionAndSuppressesLateResults() = runBlocking {
        for (failNative in listOf(false, true)) {
            val gate = VpnStartGate()
            val entered = CompletableDeferred<Unit>()
            val stopping = CompletableDeferred<Unit>()
            val finishNative = CountDownLatch(1)
            val events = mutableListOf<String>()
            try {
                val first = launch(Dispatchers.IO) {
                    gate.run { attempt ->
                        try {
                            attempt.connect(5_000) {
                                entered.complete(Unit)
                                assertTrue(finishNative.await(5, TimeUnit.SECONDS))
                                if (failNative) error("late native failure")
                            }
                            attempt.publish { events += "connected" }
                        } catch (_: Exception) {
                            attempt.publish { events += "error" }
                        }
                    }
                }
                entered.await()
                val stop = launch {
                    gate.stop(onStopping = {
                        events += "disconnecting"
                        stopping.complete(Unit)
                    }) { events += "disconnected" }
                }
                stopping.await()
                assertEquals(listOf("disconnecting"), events)
                assertFalse(stop.isCompleted)
                assertFalse(gate.run { error("stop still owns teardown") })

                finishNative.countDown()
                first.join()
                stop.join()
                assertEquals(listOf("disconnecting", "disconnected"), events)
                assertTrue(gate.run {})
            } finally {
                finishNative.countDown()
            }
        }
    }

    @Test(timeout = 10_000)
    fun stopAfterTimeoutSuppressesLateSuccess() = runBlocking {
        val gate = VpnStartGate()
        val entered = CompletableDeferred<Unit>()
        val timedOut = CompletableDeferred<Unit>()
        val stopping = CompletableDeferred<Unit>()
        val release = CountDownLatch(1)
        var connected = false
        try {
            val first = launch {
                gate.run { attempt ->
                    attempt.connect(200, onTimeout = { timedOut.complete(Unit) }) {
                        entered.complete(Unit)
                        assertTrue(release.await(5, TimeUnit.SECONDS))
                    }
                    attempt.publish { connected = true }
                }
            }
            entered.await()
            timedOut.await()
            val stop = launch {
                gate.stop(onStopping = { stopping.complete(Unit) }) {}
            }
            stopping.await()
            assertFalse(gate.run {})
            release.countDown()
            first.join()
            stop.join()
            assertFalse(connected)
            assertTrue(gate.run {})
        } finally {
            release.countDown()
        }
    }

    @Test(timeout = 10_000)
    fun stopsAreSerializedAndRejectStartsThroughTeardown() = runBlocking {
        val gate = VpnStartGate()
        val firstStopped = CompletableDeferred<Unit>()
        val finishFirst = CompletableDeferred<Unit>()
        val secondRequested = CompletableDeferred<Unit>()
        val secondStopped = CompletableDeferred<Unit>()
        val finishSecond = CompletableDeferred<Unit>()
        val first = launch {
            gate.stop {
                firstStopped.complete(Unit)
                finishFirst.await()
            }
        }
        firstStopped.await()
        val second = launch {
            gate.stop(onStopping = { secondRequested.complete(Unit) }) {
                secondStopped.complete(Unit)
                finishSecond.await()
            }
        }
        secondRequested.await()
        assertFalse(secondStopped.isCompleted)
        assertFalse(gate.run {})
        finishFirst.complete(Unit)
        first.join()
        secondStopped.await()
        assertFalse(gate.run {})
        finishSecond.complete(Unit)
        second.join()
        assertTrue(gate.run {})
    }

    @Test(timeout = 10_000)
    fun restartWaitsForCurrentStartupBeforeTouchingResources() = runBlocking {
        val gate = VpnStartGate()
        val prepared = CompletableDeferred<Unit>()
        val finish = CompletableDeferred<Unit>()
        var foregroundRequested = false
        var restarted = false
        val first = launch {
            gate.run {
                prepared.complete(Unit)
                finish.await()
            }
        }
        prepared.await()
        val restart = async(start = CoroutineStart.UNDISPATCHED) {
            gate.run(waitForIdle = true, onRequest = { foregroundRequested = true }) { restarted = true }
        }
        assertFalse(foregroundRequested)
        assertFalse(restarted)
        finish.complete(Unit)
        first.join()
        assertTrue(restart.await())
        assertTrue(foregroundRequested)
        assertTrue(restarted)
    }

    @Test(timeout = 10_000)
    fun stopRejectsQueuedRestarts() = runBlocking {
        val gate = VpnStartGate()
        val prepared = CompletableDeferred<Unit>()
        val stopping = CompletableDeferred<Unit>()
        val first = launch {
            gate.run {
                prepared.complete(Unit)
                CompletableDeferred<Unit>().await()
            }
        }
        prepared.await()
        val restart = async(start = CoroutineStart.UNDISPATCHED) {
            gate.run(waitForIdle = true) { error("restart must not undo Stop") }
        }
        val stop = launch {
            gate.stop(onStopping = { stopping.complete(Unit) }) {
                assertFalse(gate.run(waitForIdle = true) { error("stop is still running") })
            }
        }
        stopping.await()
        first.join()
        assertFalse(restart.await())
        stop.join()
        assertTrue(gate.run {})
    }

    @Test(timeout = 10_000)
    fun duplicateRejectedByInFlightStartReportsStartInProgress() = runBlocking {
        val gate = VpnStartGate()
        val prepared = CompletableDeferred<Unit>()
        val finish = CompletableDeferred<Unit>()
        val rejections = mutableListOf<VpnStartGate.Rejection>()
        val first = launch {
            gate.run {
                prepared.complete(Unit)
                finish.await()
            }
        }
        prepared.await()

        assertFalse(gate.run(onRejected = { rejections.add(it) }) { error("duplicate must not run") })
        assertEquals(listOf(VpnStartGate.Rejection.START_IN_PROGRESS), rejections)

        finish.complete(Unit)
        first.join()
        assertTrue(gate.run(onRejected = { error("accepted start must not report a rejection") }) {})
    }

    @Test(timeout = 10_000)
    fun startsRejectedByStopReportStopping() = runBlocking {
        val gate = VpnStartGate()
        val entered = CompletableDeferred<Unit>()
        val finish = CompletableDeferred<Unit>()
        val rejections = mutableListOf<VpnStartGate.Rejection>()
        val stop = launch {
            gate.stop {
                entered.complete(Unit)
                finish.await()
            }
        }
        entered.await()

        // Rejected up front: a stop is already pending.
        assertFalse(gate.run(onRejected = { rejections.add(it) }) { error("stop is running") })
        finish.complete(Unit)
        stop.join()

        // Rejected after waiting: a restart queued before Stop finished must not reconnect.
        val prepared = CompletableDeferred<Unit>()
        val busy = launch {
            gate.run {
                prepared.complete(Unit)
                CompletableDeferred<Unit>().await()
            }
        }
        prepared.await()
        val restart = async(start = CoroutineStart.UNDISPATCHED) {
            gate.run(waitForIdle = true, onRejected = { rejections.add(it) }) { error("restart must not undo Stop") }
        }
        val secondStop = launch { gate.stop {} }
        busy.join()
        assertFalse(restart.await())
        secondStop.join()

        assertEquals(listOf(VpnStartGate.Rejection.STOPPING, VpnStartGate.Rejection.STOPPING), rejections)
        assertTrue(gate.run {})
    }

    @Test(timeout = 10_000)
    fun rejectedCleanupCannotRemoveALaterStartsForegroundNotification() = runBlocking {
        val gate = VpnStartGate()
        val foreground = AtomicBoolean()
        val stopping = CompletableDeferred<Unit>()
        val finishStop = CompletableDeferred<Unit>()
        val cleaningUp = CountDownLatch(1)
        val finishCleanup = CountDownLatch(1)
        val nextRequested = CountDownLatch(1)
        val nextStarted = CountDownLatch(1)
        try {
            val stop = launch(Dispatchers.IO) {
                gate.stop {
                    foreground.set(false)
                    stopping.complete(Unit)
                    finishStop.await()
                }
            }
            stopping.await()
            val rejected = async(Dispatchers.IO) {
                var promotedHere = false
                gate.run(
                    onRequest = { promotedHere = !foreground.getAndSet(true) },
                    onRejected = { reason ->
                        assertEquals(VpnStartGate.Rejection.STOPPING, reason)
                        cleaningUp.countDown()
                        assertTrue(finishCleanup.await(5, TimeUnit.SECONDS))
                        if (promotedHere) foreground.set(false)
                    },
                ) { error("start during Stop must be rejected") }
            }
            assertTrue(cleaningUp.await(5, TimeUnit.SECONDS))
            finishStop.complete(Unit)
            val next = async(Dispatchers.IO) {
                nextRequested.countDown()
                stop.join()
                gate.run(onRequest = { foreground.set(true) }) {
                    nextStarted.countDown()
                }
            }
            assertTrue(nextRequested.await(5, TimeUnit.SECONDS))
            // Give the next request a chance to expose cleanup running outside the gate.
            nextStarted.await(200, TimeUnit.MILLISECONDS)
            finishCleanup.countDown()

            assertFalse(rejected.await())
            assertTrue(next.await())
            assertTrue("rejected cleanup removed the new start's notification", foreground.get())
        } finally {
            finishStop.complete(Unit)
            finishCleanup.countDown()
        }
    }

    @Test(timeout = 10_000)
    fun cancellingStopDoesNotAbandonTeardown() = runBlocking {
        val gate = VpnStartGate()
        val entered = CompletableDeferred<Unit>()
        val finish = CompletableDeferred<Unit>()
        var cleanedUp = false
        val stop = launch {
            gate.stop {
                entered.complete(Unit)
                finish.await()
                cleanedUp = true
            }
        }
        entered.await()
        stop.cancel()
        assertFalse(gate.run {})
        finish.complete(Unit)
        stop.join()
        assertTrue(cleanedUp)
        assertTrue(gate.run {})
    }

    @Test
    fun stopFailureDoesNotLeakTheGate() = runBlocking {
        val gate = VpnStartGate()
        val failure = runCatching { gate.stop { error("native stop failed") } }
        assertTrue(failure.isFailure)
        assertTrue(gate.run {})
    }

    private class QueuedDispatcher : CoroutineDispatcher() {
        private val queue = ArrayDeque<Runnable>()

        override fun dispatch(context: CoroutineContext, block: Runnable) {
            queue.addLast(block)
        }

        fun runQueued() {
            while (queue.isNotEmpty()) queue.removeFirst().run()
        }
    }
}
