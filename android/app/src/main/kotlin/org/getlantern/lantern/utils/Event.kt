package org.getlantern.lantern.utils

import androidx.annotation.Nullable

/**
 * Used as a wrapper for data that is exposed via a LiveData that represents an event.
 */
class Event<T>(content: T) {
    private val mContent: T

    private var hasBeenHandled = false


    init {
        requireNotNull(content) { "null values in Event are not allowed." }
        mContent = content
    }

    @get:Nullable
    val contentIfNotHandled: T?
        get() {
            if (hasBeenHandled) {
                return null
            } else {
                hasBeenHandled = true
                return mContent
            }
        }

    fun hasBeenHandled(): Boolean {
        return hasBeenHandled
    }
}