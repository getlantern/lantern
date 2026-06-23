package org.getlantern.lantern.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.Service.STOP_FOREGROUND_REMOVE
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.getSystemService
import org.getlantern.lantern.BuildConfig
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.MainActivity
import org.getlantern.lantern.R
import org.getlantern.lantern.service.LanternVpnService
import org.getlantern.lantern.service.LanternVpnService.Companion.ACTION_STOP_VPN
import org.getlantern.lantern.utils.AppLogger


class NotificationHelper {

    companion object {
        private const val DATA_USAGE = 36
        const val VPN_CONNECTED = 37
        private const val CHANNEL_VPN = "lantern_vpn"
        private const val CHANNEL_DATA_USAGE = "data_usage"
        const val OPEN_URL = "SERVICE_OPEN_URL"

        var notificationManager = LanternApp.application.getSystemService<NotificationManager>()!!
        val flags =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

        fun hasPermission(): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                return true
            }
            return notificationManager.areNotificationsEnabled()
        }

    }

    private lateinit var dataUsageNotificationChannel: NotificationChannel
    private lateinit var vpnNotificationChannel: NotificationChannel
    private val notificationSmallIconId: Int by lazy { resolveNotificationSmallIcon() }


    init {
        createDefaultNotificationChannel()
    }


    /**
     * Creates the notification channel if running on Android O or above.
     */
    private fun createDefaultNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vpnNotificationChannel = NotificationChannel(
                CHANNEL_VPN,
                BuildConfig.NOTIFICATION_CHANNEL_VPN,
                NotificationManager.IMPORTANCE_HIGH,
            )
            notificationManager.createNotificationChannel(vpnNotificationChannel)

            dataUsageNotificationChannel = NotificationChannel(
                CHANNEL_DATA_USAGE,
                BuildConfig.NOTIFICATION_CHANNEL_DATA_USAGE,
                NotificationManager.IMPORTANCE_HIGH,
            )
            notificationManager.createNotificationChannel(dataUsageNotificationChannel)
        }
    }

    private fun createNotificationChannel(identifier: String, typeName: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                identifier,
                typeName,
                NotificationManager.IMPORTANCE_HIGH,
            )
            notificationManager.createNotificationChannel(channel)
        }
    }


    private fun buildVpnNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            LanternApp.application,
            0,
            Intent(LanternApp.application, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(LanternApp.application, CHANNEL_VPN)
            .setShowWhen(false)
            .setOngoing(true)
            .setContentTitle(BuildConfig.NOTIFICATION_TITLE)
            .setContentText(BuildConfig.NOTIFICATION_CONNECTED_TEXT)
            .setOnlyAlertOnce(true)
            .setSmallIcon(notificationSmallIconId)
            .addAction(
                NotificationCompat.Action.Builder(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    BuildConfig.NOTIFICATION_DISCONNECT_ACTION,
                    disconnectVPN()
                ).build()
            )
            .setContentIntent(contentIntent)
            .build()

    }

    private fun buildStartingVpnNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            LanternApp.application,
            0,
            Intent(LanternApp.application, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(LanternApp.application, CHANNEL_VPN)
            .setShowWhen(false)
            .setOngoing(true)
            .setContentTitle(BuildConfig.NOTIFICATION_TITLE)
            .setContentText(BuildConfig.NOTIFICATION_STARTING_TEXT)
            .setOnlyAlertOnce(true)
            .setSmallIcon(notificationSmallIconId)
            .setContentIntent(contentIntent)
            .setSilent(true)
            .build()

    }

    private fun disconnectVPN(): PendingIntent {
        val intent = Intent(ACTION_STOP_VPN).setPackage(
            LanternApp.application.packageName
        )
        return PendingIntent.getBroadcast(
            LanternApp.application,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }


    fun showVPNConnectedNotification(vpnService: LanternVpnService) {
        updateForegroundNotification()
    }

    fun stopVPNConnectedNotification(vpnService: LanternVpnService) {
        stopForegroundNotification(vpnService)
    }

    /**
     * Shows the starting VPN notification as a foreground notification.
     * Also starts the service in the foreground and promotes it to a foreground service.
     */
    fun showStartingVPNConnectedNotification(vpnService: LanternVpnService) {
        showForegroundNotification(vpnService, VPN_CONNECTED, buildStartingVpnNotification())
    }

    /**
     * Shows the notification as a foreground notification.
     *
     * @param service The service to promote to foreground.
     * @param notificationId The unique notification ID.
     * @param notification The notification object built via [buildNotification].
     */
    private fun showForegroundNotification(service: Service,
        notificationId: Int,
        notification: Notification
    ) {
        AppLogger.d("Notification","Showing foreground notification with ID: $notificationId")
        service.startForeground(notificationId, notification)
    }

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


    /**
     * Updates the existing foreground notification.
     */
    private fun updateForegroundNotification() {
        AppLogger.d("Notification","Updating foreground VPN notification")
        val notification = buildVpnNotification()
        notificationManager.notify(VPN_CONNECTED, notification)
    }


    fun sendNotification(notification: lantern.io.libbox.Notification?) {
        createNotificationChannel(notification!!.identifier, notification!!.typeName)
        val builder = NotificationCompat.Builder(LanternApp.application, notification?.identifier!!)
            .setContentTitle(notification.title)
            .setContentText(notification.body)
            .setOnlyAlertOnce(true)
            .setSmallIcon(notificationSmallIconId)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
        if (!notification.subtitle.isNullOrBlank()) {
            builder.setContentInfo(notification.subtitle)
        }
        if (!notification.openURL.isNullOrBlank()) {
            builder.setContentIntent(
                PendingIntent.getActivity(
                    LanternApp.application,
                    0,
                    Intent(
                        LanternApp.application, MainActivity::class.java
                    ).apply {
                        setAction(OPEN_URL).setData(Uri.parse(notification.openURL))
                        setFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    },
                    flags,
                )
            )
        }
        notificationManager.notify(notification.typeID, builder.build())
    }

    private fun resolveNotificationSmallIcon(): Int {
        val configured = BuildConfig.NOTIFICATION_SMALL_ICON.removePrefix("@")
        val parts = configured.split("/", limit = 2)
        if (parts.size == 2) {
            val resolved = LanternApp.application.resources.getIdentifier(
                parts[1],
                parts[0],
                LanternApp.application.packageName,
            )
            if (resolved != 0) {
                return resolved
            }
        }
        // Stealth builds must never fall back to the branded icon, even when
        // the configured resource fails to resolve.
        return if (BuildConfig.STEALTH_ENABLED) {
            R.drawable.neutral_notification_icon
        } else {
            R.drawable.lantern_notification_icon
        }
    }
}
