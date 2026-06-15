package foundation.bridge

import android.app.Application
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import java.io.File
import java.util.Locale
import java.util.concurrent.atomic.AtomicReference

object BridgeContext {
    lateinit var application: Application
}

object BridgeState {
    private val current = AtomicReference("disconnected")
    private val error = AtomicReference<String?>(null)

    fun get(): String = current.get()
    fun getError(): String? = error.get()

    fun set(value: String) {
        if (value != "error") error.set(null)
        current.set(value)
    }

    fun setError(message: String) {
        error.set(message)
        current.set("error")
    }
}

object BridgePaths {
    fun dataDir(context: Context): String = ensure(context.filesDir, "data")

    fun logDir(context: Context): String = ensure(context.filesDir, "logs")

    fun deviceId(context: Context): String {
        return Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ANDROID_ID,
        ) ?: "android"
    }

    fun locale(): String = Locale.getDefault().toLanguageTag()

    private fun ensure(root: File, name: String): String {
        val dir = File(root, name)
        dir.mkdirs()
        return dir.absolutePath
    }
}

object BridgeNotification {
    private const val CHANNEL_ID = "connection"
    private const val NOTIFICATION_ID = 9842

    fun show(service: Service, text: String) {
        createChannel(service)
        service.startForeground(NOTIFICATION_ID, build(service, text))
    }

    fun clear(service: Service) {
        service.stopForeground(Service.STOP_FOREGROUND_REMOVE)
    }

    private fun build(context: Context, text: String): android.app.Notification {
        val intent = Intent(context, HomeActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_LOW)
        }
        return builder
            .setSmallIcon(R.drawable.neutral_notification_icon)
            .setContentTitle(context.getString(R.string.app_name))
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Connection",
            NotificationManager.IMPORTANCE_LOW,
        )
        context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }
}
