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

    /** Ordinary starts are rejected while busy; a restart may wait for the current attempt. */
    suspend fun run(
        waitForIdle: Boolean = false,
        block: suspend (Attempt) -> Unit,
    ): Boolean = coroutineScope {
        val job = coroutineContext.job
        val generation = synchronized(stateLock) {
            if (pendingStops != 0) return@coroutineScope false
            stopGeneration
        }
        if (waitForIdle) operationMutex.lock()
        synchronized(stateLock) {
            // A restart queued before Stop must not reconnect after teardown.
            if (pendingStops != 0 || generation != stopGeneration) {
                if (waitForIdle) operationMutex.unlock()
                return@coroutineScope false
            }
            if (!waitForIdle && !operationMutex.tryLock()) return@coroutineScope false
            activeStart = job
        }
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
