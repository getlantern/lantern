package org.getlantern.lantern.utils

import androidx.lifecycle.MutableLiveData

/**
 * Singleton to manage VPN status using LiveData.
 */
object VpnStatusManager {
    val statusLiveData = MutableLiveData<Result<String>>()

    /**
     * Utility function to post success or failure to LiveData.
     *
     * @param successMessage Success message when the operation completes successfully.
     * @param error Exception in case of failure. Pass null if successful.
     */
    fun postStatus(successMessage: String? = null, error: Throwable? = null) {
        if (error != null) {
            statusLiveData.postValue(Result.failure(error))
        } else {
            statusLiveData.postValue(Result.success(successMessage ?: "Success"))
        }
    }
}