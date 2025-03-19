package org.getlantern.lantern

import android.app.Application
import android.content.Context

class LanternApp : Application() {

    companion object {
        lateinit var application: LanternApp
    }

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        application = this
    }


}