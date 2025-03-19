package org.getlantern.lantern

import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import org.getlantern.lantern.handler.MethodHandler


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

    }


}
