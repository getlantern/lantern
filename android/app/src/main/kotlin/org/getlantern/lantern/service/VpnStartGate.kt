package org.getlantern.lantern.service

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.job
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/**
 * Gives one VPN start ownership of shared setup and cleanup.
 * Stop cancels that attempt and waits for its native call before tearing down.
 */
internal class VpnStartGate(
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    private val stateLock = Any()
    private val operationMutex = Mutex()
    private var activeStart: Job? = null
    private var pendingStops = 0
    private var stopGeneration = 0L

    /** Why [run] declined a start. Decided atomically with the gate state. */
    enum class Rejection {
        /** Another start owns the gate and will publish its own result. */
        START_IN_PROGRESS,
        /** A stop is running or completed while this start waited; nothing owns startup. */
        STOPPING,
    }

    /**
     * Ordinary starts are rejected while busy; a restart may wait for the current attempt.
     * [onRejected] runs, outside the lock, with the reason when the start is declined.
     */
    suspend fun run(
        waitForIdle: Boolean = false,
        onRejected: (Rejection) -> Unit = {},
        block: suspend (Attempt) -> Unit,
    ): Boolean = coroutineScope {
        val job = coroutineContext.job
        val generation = synchronized(stateLock) {
            if (pendingStops != 0) null else stopGeneration
        } ?: return@coroutineScope reject(Rejection.STOPPING, onRejected)
        if (waitForIdle) operationMutex.lock()
        val rejection = synchronized(stateLock) {
            // A restart queued before Stop must not reconnect after teardown.
            if (pendingStops != 0 || generation != stopGeneration) {
                if (waitForIdle) operationMutex.unlock()
                return@synchronized Rejection.STOPPING
            }
            if (!waitForIdle && !operationMutex.tryLock()) return@synchronized Rejection.START_IN_PROGRESS
            activeStart = job
            null
        }
        if (rejection != null) return@coroutineScope reject(rejection, onRejected)
        try {
            job.ensureActive()
            block(Attempt(job))
            true
        } finally {
            synchronized(stateLock) {
                activeStart = null
                operationMutex.unlock()
            }
        }
    }

    private fun reject(rejection: Rejection, onRejected: (Rejection) -> Unit): Boolean {
        onRejected(rejection)
        return false
    }

    suspend fun stop(
        onStopping: () -> Unit = {},
        block: suspend () -> Unit,
    ) = withContext(NonCancellable) {
        synchronized(stateLock) {
            pendingStops++
            stopGeneration++
            activeStart?.cancel()
        }
        try {
            onStopping()
            operationMutex.withLock { block() }
        } finally {
            synchronized(stateLock) { pendingStops-- }
        }
    }

    inner class Attempt internal constructor(private val job: Job) {
        // Serialize status publication with Stop so a cancelled attempt cannot
        // restore Connected or its notification after Disconnecting is posted.
        fun publish(block: () -> Unit) = synchronized(stateLock) {
            if (job.isActive) block()
        }

        suspend fun connect(
            timeoutMillis: Long,
            onTimeout: () -> Unit = {},
            connect: () -> Unit,
        ) = coroutineScope {
            val deadline = launch {
                delay(timeoutMillis)
                publish(onTimeout)
            }
            try {
                // JNI is not cancellable. Keep its caller alive until it returns
                // so success, failure, and Stop all finish through the same path.
                withContext(dispatcher) { connect() }
            } finally {
                deadline.cancel()
            }
        }
    }
}
