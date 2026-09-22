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
        /** A stop is running or superseded this request. */
        STOPPING,
    }

    /**
     * Ordinary starts are rejected while busy; a restart may wait for the current attempt.
     * [onRequest] and [onRejected] run under the same lock as the decision, so rejected
     * requests finish their foreground cleanup before another start can be admitted.
     */
    suspend fun run(
        waitForIdle: Boolean = false,
        onRequest: () -> Unit = {},
        onRejected: (Rejection) -> Unit = {},
        block: suspend (Attempt) -> Unit,
    ): Boolean = coroutineScope {
        val job = coroutineContext.job
        val generation = synchronized(stateLock) {
            if (pendingStops != 0) {
                onRequest()
                return@coroutineScope reject(Rejection.STOPPING, onRejected)
            }
            stopGeneration
        }
        if (waitForIdle) operationMutex.lock()
        var ownsOperation = waitForIdle
        try {
            synchronized(stateLock) {
                onRequest()
                // A restart queued before Stop must not reconnect after teardown.
                if (pendingStops != 0 || generation != stopGeneration) {
                    return@coroutineScope reject(Rejection.STOPPING, onRejected)
                }
                if (!waitForIdle) {
                    ownsOperation = operationMutex.tryLock()
                    if (!ownsOperation) return@coroutineScope reject(Rejection.START_IN_PROGRESS, onRejected)
                }
                activeStart = job
            }
            job.ensureActive()
            block(Attempt(job))
            true
        } finally {
            synchronized(stateLock) {
                if (ownsOperation) {
                    if (activeStart === job) activeStart = null
                    operationMutex.unlock()
                }
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
