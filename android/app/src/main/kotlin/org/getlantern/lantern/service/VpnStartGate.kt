package org.getlantern.lantern.service

import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.withTimeout

/**
 * Gives one VPN start ownership of shared setup and cleanup.
 * Ownership lasts until the caller's block and any native call have finished.
 */
internal class VpnStartGate(
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    private val inFlight = AtomicBoolean(false)

    /** Returns false without running or queuing [block] if another start owns the gate. */
    suspend fun run(block: suspend (Attempt) -> Unit): Boolean {
        if (!inFlight.compareAndSet(false, true)) return false

        val attempt = Attempt(dispatcher)
        try {
            block(attempt)
        } finally {
            // Cleanup must finish before another attempt can touch the monitor.
            attempt.onConnectFinished { inFlight.set(false) }
        }
        return true
    }

    class Attempt internal constructor(private val dispatcher: CoroutineDispatcher) {
        private var connection: Deferred<Unit>? = null

        val isConnectRunning: Boolean
            get() = connection?.isCompleted == false

        suspend fun connect(timeoutMillis: Long, connect: () -> Unit) {
            // JNI can keep running after cancellation, so it has its own job.
            // The caller can time out without releasing the gate early.
            val scope = CoroutineScope(SupervisorJob() + dispatcher)
            try {
                val deferred = scope.async { connect() }
                connection = deferred
                withTimeout(timeoutMillis) { deferred.await() }
            } finally {
                scope.cancel()
            }
        }

        internal fun onConnectFinished(release: () -> Unit) {
            val deferred = connection
            if (deferred == null) {
                release()
            } else {
                deferred.invokeOnCompletion { release() }
            }
        }
    }
}
