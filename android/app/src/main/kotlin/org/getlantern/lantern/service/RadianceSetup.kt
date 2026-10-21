package org.getlantern.lantern.service

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import lantern.io.mobile.Mobile
import lantern.io.utils.Opts
import lantern.io.utils.PlatformInterface
import org.getlantern.lantern.utils.FlutterEventListener

/**
 * Process-wide Radiance backend setup. The VPN and no-VPN services both bring
 * the backend up here, so callers waiting on readiness are released by either.
 */
internal object RadianceSetup {
    private sealed class State {
        data object Initializing : State()
        data object Ready : State()
        data class Failed(val cause: Throwable) : State()
    }

    private val state = MutableStateFlow<State>(State.Initializing)
    private val setupMutex = Mutex()

    suspend fun awaitReady() {
        if (Mobile.isRadianceConnected()) return
        when (val current = state.first { it !is State.Initializing }) {
            State.Ready -> check(Mobile.isRadianceConnected()) {
                "Radiance setup completed but the core is unavailable"
            }
            is State.Failed -> throw current.cause
            State.Initializing -> error("Radiance is still initializing")
        }
    }

    /** Blocking JNI; call off the main thread. */
    suspend fun setup(
        platform: PlatformInterface,
        opts: () -> Opts,
        listener: FlutterEventListener,
    ) {
        setupMutex.withLock {
            if (Mobile.isRadianceConnected()) {
                state.value = State.Ready
                return@withLock
            }

            state.value = State.Initializing
            try {
                Mobile.startIPCServer(platform, opts())
                Mobile.setupRadiance(opts(), listener)
                state.value = State.Ready
            } catch (e: Exception) {
                state.value = State.Failed(e)
                throw e
            }
        }
    }
}
