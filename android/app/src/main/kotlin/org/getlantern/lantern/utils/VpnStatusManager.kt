package org.getlantern.lantern.utils

import androidx.lifecycle.MutableLiveData
import org.getlantern.lantern.constant.VPNStatus

/**
 * Singleton to manage VPN status using LiveData.
 */
object VpnStatusManager {
    val statusLiveData = MutableLiveData<Event<Result<String>>>()
    val vpnStatus = MutableLiveData<Event<VPNStatus>>()

//    fun postStatus(successMessage: String? = null, error: Throwable? = null) {
//        val result = if (error != null) {
//            Result.failure<String>(error)
//        } else {
//            Result.success(successMessage ?: "Success")
//        }
//        statusLiveData.postValue(Event(result))
//    }


    fun postVPNStatus(status: VPNStatus) {
        vpnStatus.postValue(Event(status))
    }

    fun postVPNError(errorCode: String, errorMessage: String, error: Throwable?) {
        val errorStatus = VPNStatus.error(errorCode, errorMessage, error)
        vpnStatus.postValue(Event(errorStatus))
    }
}