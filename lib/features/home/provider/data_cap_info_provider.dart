import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/services/notification_service.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/services/injection_container.dart' show sl;

part 'data_cap_info_provider.g.dart';

@Riverpod(keepAlive: true)
class DataCapInfoNotifier extends _$DataCapInfoNotifier {
  @override
  Future<DataCapUsageResponse> build() async {
    final result = await ref.read(lanternServiceProvider).getDataCapInfo();
    return result.fold(
      (failure) {
        throw Exception('Failed to fetch data cap info: $failure');
      },
      (dataCapInfo) {
        checkAndNotify(dataCapInfo);
        return dataCapInfo;
      },
    );
  }

  void updateDataCapInfo(DataCapUsageResponse newInfo) {
    state = AsyncValue.data(newInfo);
    checkAndNotify(newInfo);
  }

  /// Main entry point - checks usage and sends notification if threshold crossed
  Future<void> checkAndNotify(DataCapUsageResponse dataCapInfo) async {
    final usagePercent = _calculateUsagePercent(dataCapInfo);
    final threshold = _getThreshold(usagePercent);
    appLogger.debug(
        'Data cap usage at ${usagePercent.toStringAsFixed(2)}%, threshold: $threshold');
    if (threshold == null) return;
    final shouldNotify = await _shouldSendNotification(threshold, dataCapInfo);
    if (!shouldNotify) return;
    _sendNotification(threshold, dataCapInfo);
    _saveNotifiedThreshold(threshold, dataCapInfo);
  }

  double _calculateUsagePercent(DataCapUsageResponse dataCapUsage) {
    if (!dataCapUsage.enabled) {
      return 0.0;
    }
    final dataCapInfo = dataCapUsage.usage;
    if (dataCapInfo == null) {
      return 0.0;
    }
    if (dataCapInfo.bytesAllotted <= 0) {
      return 0.0;
    }
    return (dataCapInfo.bytesUsed / dataCapInfo.bytesAllotted) * 100;
  }

  /// Determines if a notification should be sent based on the saved threshold
  Future<bool> _shouldSendNotification(
      DataCapThreshold threshold, DataCapUsageResponse dataCapInfo) async {
    final usage = dataCapInfo.usage;
    if (usage?.allotmentEndTime == null) return true;
    final appSetting = ref.read(appSettingProvider);
    final savedThreshold = appSetting.dataCapThreshold;
    // First time or empty
    if (savedThreshold.isEmpty) return true;
    final parts = savedThreshold.split('_');
    if (parts.length != 2) return true;
    final savedResetTime = parts[0];
    final savedThresholdValue = int.tryParse(parts[1]) ?? 0;
    // New day - reset cycle
    if (savedResetTime != usage!.allotmentEndTime) return true;
    // Same day - only notify if crossing higher threshold
    final showNotification = threshold.value > savedThresholdValue;
    appLogger.debug('_shouldSendNotification '
        'for threshold ${threshold.value}, '
        'saved threshold: $savedThresholdValue, '
        'showNotification: $showNotification');
    return showNotification;
  }

  /// Sends the notification using the NotificationService
  void _sendNotification(DataCapThreshold threshold,
      DataCapUsageResponse dataUsageResponse) async {
    final dataCapInfo = dataUsageResponse.usage!;
    final notification = _buildNotificationContent(threshold, dataCapInfo);

    await sl<NotificationService>().showNotification(
      id: threshold.value,
      title: notification.$1,
      body: notification.$2,
      notificationType: NotificationType.dataCapWarning,
    );
  }

  (String, String) _buildNotificationContent(
      DataCapThreshold threshold, DataCapUsageDetails dataCapInfo) {
    final usedMB = (dataCapInfo.bytesUsed / (1024 * 1024)).round();
    final limitMB = (dataCapInfo.bytesAllotted / (1024 * 1024)).round();
    final remainingMB = limitMB - usedMB;
    final resetTime = formatDailyResetTime(dataCapInfo.allotmentEndTime);

    switch (threshold) {
      case DataCapThreshold.half:
        return (
          'mb_free_data_remaining'.i18n.fill([remainingMB]),
          'daily_data_cap_reached_notification_message'.i18n.fill([resetTime]),
        );

      case DataCapThreshold.high:
        return (
          'mb_free_data_remaining'.i18n.fill([remainingMB]),
          'daily_data_cap_reached_notification_message'.i18n.fill([resetTime]),
        );

      case DataCapThreshold.full:
        return (
          'daily_data_cap_reached'.i18n,
          'daily_data_cap_reached_notification_message'.i18n.fill([resetTime]),
        );
    }
  }

  String formatDailyResetTime(String serverTime) {
    try {
      if (serverTime.isEmpty) {
        return "";
      }
      final DateTime endTime = DateTime.parse(
        serverTime,
      ).toLocal();
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final DateTime endDate =
          DateTime(endTime.year, endTime.month, endTime.day);
      if (endDate == today) {
        return AppDateFormats.time.format(endTime);
      }

      return '${AppDateFormats.weekday.format(endTime)}, '
          '${AppDateFormats.time.format(endTime)}';
    } catch (e) {
      appLogger.error('Error formatting daily reset time: $e');
      return "";
    }
  }

  void _saveNotifiedThreshold(
      DataCapThreshold threshold, DataCapUsageResponse dataCapInfo) {
    final usage = dataCapInfo.usage!;
    final thresholdValue = '${usage.allotmentEndTime}_${threshold.value}';
    final appSettingNotifier = ref.read(appSettingProvider.notifier);
    appLogger.debug(
        'Saving notified threshold: $thresholdValue for end time: ${usage.allotmentEndTime}');
    appSettingNotifier.updateDataCapThreshold(thresholdValue);
  }
}

enum DataCapThreshold {
  half(50),
  high(80),
  full(100);

  final int value;

  const DataCapThreshold(this.value);
}

DataCapThreshold? _getThreshold(double usagePercent) {
  if (usagePercent >= 100) return DataCapThreshold.full;
  if (usagePercent >= 80) return DataCapThreshold.high;
  if (usagePercent >= 50) return DataCapThreshold.half;
  return null;
}
