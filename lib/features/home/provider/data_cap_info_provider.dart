import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/services/notification_service.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
        return dataCapInfo;
      },
    );
  }

  void updateDateCapInfo(DataCapUsageResponse newInfo) {
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

    final shouldNotify = await _shouldSendNotification(threshold);
    if (!shouldNotify) return;

    _sendNotification(threshold, dataCapInfo);
    _saveNotifiedThreshold(threshold);
  }

  double _calculateUsagePercent(DataCapUsageResponse dataCapUsage) {
    if (!dataCapUsage.enabled) {
      return 0.0;
    }
    final dataCapInfo = dataCapUsage.usage!;
    return (dataCapInfo.bytesUsed / dataCapInfo.bytesAllotted) * 100;
  }

  Future<bool> _shouldSendNotification(DataCapThreshold threshold) async {
    final appSetting = ref.read(appSettingProvider);
    final lastNotified = int.tryParse(appSetting.dataCapThreshold) ?? 0;
    return threshold.value > lastNotified;
  }

  void _sendNotification(DataCapThreshold threshold,
      DataCapUsageResponse dataUsageResponse) async {
    final dataCapInfo = dataUsageResponse.usage!;
    final notification = _buildNotificationContent(threshold, dataCapInfo);

    await ref.read(notificationServiceProvider).showNotification(
        id: threshold.value, title: notification.$1, body: notification.$1);
  }

  (String, String) _buildNotificationContent(
      DataCapThreshold threshold, DataCapUsageDetails dataCapInfo) {
    final usedMB = (dataCapInfo.bytesUsed / (1024 * 1024)).round();
    final limitMB = (dataCapInfo.bytesAllotted / (1024 * 1024)).round();
    final remainingMB = limitMB - usedMB;
    final resetTime = formatDailyResetTime(dataCapInfo.allotmentEndTime);

    switch (threshold) {
      case DataCapThreshold.medium:
        return (
          '$remainingMB MB free data remaining',
          'Your data will reset at $resetTime. Upgrade to Pro for unlimited high-speed data.'
        );

      case DataCapThreshold.high:
        return (
          '$remainingMB MB free data remaining',
          'Your data will reset at $resetTime. Upgrade to Pro for unlimited high-speed data.'
        );

      case DataCapThreshold.full:
        return (
          'Daily data cap reached',
          'Speeds reduced to 128 kb/sec until $resetTime. Upgrade to Pro for unlimited data.'
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

  void _saveNotifiedThreshold(DataCapThreshold threshold) async {
    final appSettingNotifier = ref.read(appSettingProvider.notifier);
    appSettingNotifier.updateDataCapThreshold(threshold.value.toString());
  }
}

enum DataCapThreshold {
  medium(50),
  high(80),
  full(90);

  final int value;

  const DataCapThreshold(this.value);
}

DataCapThreshold? _getThreshold(double usagePercent) {
  if (usagePercent >= 100) return DataCapThreshold.full;
  if (usagePercent >= 80) return DataCapThreshold.high;
  if (usagePercent >= 50) return DataCapThreshold.medium;
  return null;
}
