package org.getlantern.lantern.utils

import androidx.lifecycle.MutableLiveData

/**
 * Singleton to manage VPN status using LiveData.
 */
object VpnStatusManager {
    val statusLiveData = MutableLiveData<Event<Result<String>>>()

    fun postStatus(successMessage: String? = null, error: Throwable? = null) {
        val result = if (error != null) {
            Result.failure<String>(error)
        } else {
            Result.success(successMessage ?: "Success")
        }
        statusLiveData.postValue(Event(result))
    }
}