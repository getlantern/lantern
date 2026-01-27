import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/common/common.dart';
import 'package:timezone/timezone.dart' as tz;

/// Provider for the notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

enum NotificationType {
  dataCapWarning,
  main,
}

class NotificationService {
  bool _notificationsEnabled = false;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('lantern_notification_icon');
      const darwinSettings = DarwinInitializationSettings(
        requestSoundPermission: true,
        requestBadgePermission: true,
        requestAlertPermission: true,
      );
      final linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'open_notification'.i18n,
        defaultIcon: AssetsLinuxIcon(AppImagePaths.appIcon),
      );
      final windowsSettings = WindowsInitializationSettings(
        appName: 'app_name'.i18n,
        appUserModelId: AppSecrets.windowsAppUserModelId,
        guid: AppSecrets.windowsGuid,
      );
      final settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
        windows: windowsSettings,
      );
      final success = await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      );
      appLogger.info('Notification plugin initialized: $success');

      _notificationsEnabled = await _permissionsGranted() ?? false;
    } catch (e) {
      appLogger.error('Error initializing notifications: $e');
      _notificationsEnabled = false;
    }
  }

  Future<bool?> _permissionsGranted() async {
    if (Platform.isIOS) {
      return await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isMacOS) {
      return await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.requestNotificationsPermission() ??
          false;
    }
    return true;
  }

  void onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (notificationResponse.payload != null) {
      appLogger.debug('notification payload: $payload');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  /// schedules a notification to be shown after [delay]
  /// this uses zonedSchedule to ensure it works even if the app is terminated
  /// if [notificationDetails] is not provided, uses default details for main type
  Future<void> scheduleNotification(
    int id, {
    required String title,
    required String body,
    Duration? delay,
    String? payload,
    NotificationDetails? notificationDetails,
  }) async {
    final scheduleTime =
        tz.TZDateTime.now(tz.local).add(delay ?? Duration.zero);
    final nd =
        notificationDetails ?? _getNotificationDetails(NotificationType.main);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduleTime,
      nd,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// shows a notification immediately
  /// if [notificationDetails] is not provided, uses default details for main type
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    NotificationDetails? notificationDetails,
  }) {
    final notificationDetails0 =
        notificationDetails ?? _getNotificationDetails(NotificationType.main);
   return _plugin.show(id, title, body, notificationDetails0);
  }

  /// notification details based on type
  /// can be extended to have different settings per type
  NotificationDetails _getNotificationDetails(NotificationType type) {
    final priority = Priority.high;
    final importance = Importance.max;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        getNotificationChannelId(type),
        getNotificationChannel(type),
        importance: importance,
        priority: priority,
        visibility: NotificationVisibility.public,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      linux: LinuxNotificationDetails(
          urgency: LinuxNotificationUrgency.critical,
          defaultActionName: 'View'),
      windows: WindowsNotificationDetails(
        duration: WindowsNotificationDuration.short,
        audio: WindowsNotificationAudio.preset(
            sound: WindowsNotificationSound.defaultSound),
      ),
    );
  }

  /// Returns the notification channel name based on the notification type.
  String getNotificationChannel(NotificationType type) {
    switch (type) {
      case NotificationType.dataCapWarning:
        return 'data_cap_channel'.i18n;
      case NotificationType.main:
        return 'main_channel'.i18n;
    }
  }

  /// Returns the notification channel ID based on the notification type.
  String getNotificationChannelId(NotificationType type) {
    switch (type) {
      case NotificationType.dataCapWarning:
        return 'data_cap_channel';
      case NotificationType.main:
        return 'main_channel';
    }
  }
}
