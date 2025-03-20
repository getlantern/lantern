package org.getlantern.lantern

import android.content.Intent
import android.util.Log
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import org.getlantern.lantern.handler.MethodHandler
import org.getlantern.lantern.service.LanternService
import org.getlantern.lantern.utils.isServiceRunning


class MainActivity : FlutterActivity() {
    companion object {
        const val TAG = "A/MainActivity"
        lateinit var instance: MainActivity
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        ///Setup handler
        flutterEngine.plugins.add(MethodHandler(lifecycleScope))
        startLanternService()
    }

    private fun startLanternService() {
        Log.d(TAG, "Starting LanternService")
        if (isServiceRunning(this, LanternService::class.java)) {
            Log.d(TAG, "LanternService is already running")
            return
        }
        try {
            val intent = Intent(
                this,
                LanternService::class.java
            )
            startService(intent)
            Log.d(TAG, "LanternService started")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }


    override fun onDestroy() {
        super.onDestroy()

    }


}
