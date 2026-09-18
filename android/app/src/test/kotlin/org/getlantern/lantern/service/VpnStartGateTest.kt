package org.getlantern.lantern.service

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.CoroutineContext
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.yield
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
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

        assertSame(failure, result.exceptionOrNull())
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
                assertFalse(attempt.isConnectRunning)
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
    fun timeoutKeepsGateUntilBlockingConnectReturns() = runBlocking {
        val gate = VpnStartGate()
        val entered = CompletableDeferred<Unit>()
        val release = CountDownLatch(1)
        try {
            val first = async {
                gate.run { attempt ->
                    val result = runCatching {
                        attempt.connect(200) {
                            entered.complete(Unit)
                            assertTrue(release.await(5, TimeUnit.SECONDS))
                        }
                    }
                    assertTrue(result.exceptionOrNull() is TimeoutCancellationException)
                    assertTrue(attempt.isConnectRunning)
                }
            }
            entered.await()
            assertTrue(first.await())
            assertFalse(gate.run { error("native connect is still running") })
        } finally {
            release.countDown()
        }

        awaitRetry(gate)
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
            first.cancelAndJoin()

            assertFalse(gate.run { error("native connect is still running") })
        } finally {
            release.countDown()
        }

        awaitRetry(gate)
    }

    @Test(timeout = 10_000)
    fun cancellationBeforeConnectStartsDoesNotLeakGate() = runBlocking {
        val dispatcher = QueuedDispatcher()
        val gate = VpnStartGate(dispatcher)
        var connected = false
        val first = launch(start = CoroutineStart.UNDISPATCHED) {
            gate.run { attempt -> attempt.connect(5_000) { connected = true } }
        }

        first.cancelAndJoin()
        dispatcher.runQueued()

        assertFalse(connected)
        assertTrue(gate.run {})
    }

    private suspend fun awaitRetry(gate: VpnStartGate) {
        withTimeout(5_000) {
            while (!gate.run {}) yield()
        }
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
