package org.getlantern.lantern.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.Service.STOP_FOREGROUND_REMOVE
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.getSystemService
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.MainActivity
import org.getlantern.lantern.R
import org.getlantern.lantern.service.LanternVpnService
import org.getlantern.lantern.service.LanternVpnService.Companion.ACTION_STOP_VPN


class NotificationHelper {

    private val notificationManager by lazy { app.getSystemService<NotificationManager>()!! }
    private val app by lazy { LanternApp.application }

    companion object {
        private const val DATA_USAGE = 36
        const val VPN_CONNECTED = 37
        private const val CHANNEL_VPN = "lantern_vpn"
        private const val CHANNEL_DATA_USAGE = "data_usage"
        private const val VPN_DESC = "VPN"
        private const val DATA_USAGE_DESC = "Data Usage"


    }

    private lateinit var dataUsageNotificationChannel: NotificationChannel
    private lateinit var vpnNotificationChannel: NotificationChannel

    init {
        createNotificationChannel()

    }

    fun hasPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return notificationManager.areNotificationsEnabled()
    }


    /**
     * Creates the notification channel if running on Android O or above.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vpnNotificationChannel = NotificationChannel(
                CHANNEL_VPN,
                VPN_DESC,
                NotificationManager.IMPORTANCE_HIGH,
            )
            notificationManager.createNotificationChannel(vpnNotificationChannel)

            dataUsageNotificationChannel = NotificationChannel(
                CHANNEL_DATA_USAGE,
                DATA_USAGE_DESC,
                NotificationManager.IMPORTANCE_HIGH,
            )
            notificationManager.createNotificationChannel(dataUsageNotificationChannel)

        }
    }

    /**
     * Builds a notification using the provided title, content and icon.
     */
//    fun buildNotification(title: String, content: String, smallIcon: Int): Notification {
//        return NotificationCompat.Builder(context, CHANNEL_ID)
//            .setContentTitle(title)
//            .setContentText(content)
//            .setSmallIcon(smallIcon)
//            .setOngoing(true) // Prevents the notification from being swiped away.
//            .build()
//    }


    private fun buildVpnNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            app,
            0,
            Intent(app, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(app, CHANNEL_VPN)
            .setContentTitle(app.getString(R.string.disconnect))
            .addAction(
                android.R.drawable.ic_delete,
                app.getString(R.string.disconnect),
                disconnectBroadcast()
            )
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setShowWhen(true)
            .setSmallIcon(R.drawable.lantern_notification_icon)
            .build()

    }

    private fun disconnectBroadcast(): PendingIntent {

        val intent = Intent(ACTION_STOP_VPN).setPackage(
            LanternApp.application.packageName
        )
        return PendingIntent.getBroadcast(
            app,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }


    fun showVPNConnectedNotification(vpnService: LanternVpnService) {
        showForegroundNotification(vpnService, VPN_CONNECTED, buildVpnNotification())
    }

    fun stopVPNConnectedNotification(vpnService: LanternVpnService) {
        stopForegroundNotification(vpnService)
    }


    /**
     * Shows the notification as a foreground notification.
     *
     * @param service The service to promote to foreground.
     * @param notificationId The unique notification ID.
     * @param notification The notification object built via [buildNotification].
     */
    fun showForegroundNotification(
        service: Service,
        notificationId: Int,
        notification: Notification
    ) {
        service.startForeground(notificationId, notification)
    }

    /**
     * Updates the notification.
     *
     * @param notificationId The unique notification ID.
     * @param notification The updated notification object.
     */
//    fun updateNotification(notificationId: Int, notification: Notification) {
//        val notificationManager =
//            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
//        notificationManager.notify(notificationId, notification)
//    }

    /**
     * Stops the foreground notification.
     *
     * @param service The service whose foreground status should be stopped.
     * @param removeNotification Whether to remove the notification from the status bar.
     */
    private fun stopForegroundNotification(service: LanternVpnService) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            service.stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            // For API < 24, stopForeground without flags
            service.stopForeground(true)
        }
    }

}
