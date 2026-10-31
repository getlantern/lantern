package org.getlantern.lantern.utils

import android.os.Handler
import android.os.Looper
import java.util.concurrent.CopyOnWriteArrayList

/**
 * Delivers every emitted event to the listeners, in order, one dispatch per
 * event. Unlike LiveData.postValue it never coalesces: a burst of snapshots
 * cannot replace an occasional event such as selection-changed before it is
 * delivered. Events emitted while no listener is attached are dropped; the
 * app re-reads its state when it starts listening.
 */
class EventQueue<T>(
    /** Runs one delivery on the listeners' thread. Tests replace it. */
    private val dispatch: (Runnable) -> Unit = mainThread(),
) {
    private val listeners = CopyOnWriteArrayList<(T) -> Unit>()

    fun addListener(listener: (T) -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: (T) -> Unit) {
        listeners.remove(listener)
    }

    /**
     * Delivers [event] to the listeners attached now that are still attached
     * when it runs, so a listener added in between never hears it.
     * Synchronized so concurrent emits post in the order they took the lock.
     */
    @Synchronized
    fun emit(event: T) {
        // ArrayList copies through toArray, one atomic read of the
        // CopyOnWriteArrayList. toList reads the size, then the element.
        val targets = ArrayList(listeners)
        dispatch(Runnable { for (listener in targets) if (listener in listeners) listener(event) })
    }

    companion object {
        /** Posts each delivery to the main thread on its own. */
        fun mainThread(): (Runnable) -> Unit {
            val handler by lazy { Handler(Looper.getMainLooper()) }
            return { runnable -> handler.post(runnable) }
        }
    }
}
