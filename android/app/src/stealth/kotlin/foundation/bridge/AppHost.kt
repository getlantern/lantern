package foundation.bridge

import android.app.Application

class AppHost : Application() {
    override fun onCreate() {
        super.onCreate()
        BridgeContext.application = this
    }
}
