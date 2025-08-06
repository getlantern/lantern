import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/common/common.dart';
import 'package:timezone/timezone.dart' as tz;

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
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      );
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

  Future<void> showNotification(
    int id, {
    required String title,
    required String body,
    Duration? delay,
    String? payload,
  }) async {
    if (!_notificationsEnabled) {
      appLogger.debug('Notification not sent: permissions not granted.');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'main_channel',
      'Main Channel',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const macOSDetails = DarwinNotificationDetails();
    const windowsDetails = WindowsNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      macOS: macOSDetails,
      iOS: iosDetails,
      linux: linuxDetails,
      windows: windowsDetails,
    );
    final scheduleTime =
        tz.TZDateTime.now(tz.local).add(delay ?? Duration.zero);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduleTime,
      notificationDetails,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
