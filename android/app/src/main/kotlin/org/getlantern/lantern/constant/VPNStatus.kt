package org.getlantern.lantern.constant

enum class VPNStatus {
    Connecting,
    Connected,
    Disconnecting,
    Disconnected,
    MissingPermission,
    Error;


    var errorCode: String? = null
    var errorMessage: String? = null
    var error: Throwable? = null

    companion object {
        fun error(code: String, message: String,errorDetails: Throwable?): VPNStatus {
            return Error.apply {
                errorCode = code
                errorMessage = message
                error = errorDetails
            }
        }
    }

}