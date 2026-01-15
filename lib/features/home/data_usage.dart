import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/features/home/provider/data_cap_info_provider.dart';

import '../../core/common/common.dart';

class DataUsage extends ConsumerWidget {
  const DataUsage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final dataCapAsync = ref.watch(dataCapInfoProvider);
    appLogger.debug('Building DataUsage widget');
    return dataCapAsync.when(
      data: (dataCapResponse) {
        /// If data cap is not enabled, don't show the widget
        if (!dataCapResponse.enabled || dataCapResponse.usage == null) {
          return const SizedBox.shrink();
        }
        final dataCap = dataCapResponse.usage!;
        appLogger.info("dataCap: $dataCap");

        /// Do all math in BYTES
        final int totalBytes = dataCap.bytesAllotted;
        final int usedBytes = dataCap.bytesUsed.clamp(0, totalBytes);
        final int remainingBytes = totalBytes - usedBytes;
        final isDataCapReached = usedBytes >= totalBytes;
        appLogger.debug(
            "Data Usage - Bytes: $totalBytes bytes, Used: $usedBytes bytes, Remaining: $remainingBytes bytes");
        final dataCapResetTime = formatDailyResetTime(dataCap.allotmentEndTime);
        String dataCapMessage =
            "daily_data_cap_reached_message".i18n.fill([dataCapResetTime]);
        ///If parsing fails and returns empty string
        ///do not show time
        if (dataCapResetTime.isEmpty) {
          dataCapMessage = dataCapMessage.split('-').first;
        }

        /// Convert to MB only for display
        final int totalData = (totalBytes.toMB).round();
        final int remainingData = (remainingBytes.toMB).round();
        final int usedData =
            usedBytes == 0 ? 0 : max(1, usedBytes.toMB.round());
        appLogger.debug(
            "Data Usage - Total: $totalData MB, Used: $usedData MB, Remaining: $remainingData MB");

        final usageString = '$usedData/$totalData';

        final newProgress = dataCap.bytesAllotted == 0
            ? 0.0
            : (dataCap.bytesUsed / dataCap.bytesAllotted).clamp(0.0, 1.0);

        return Container(
          decoration: BoxDecoration(boxShadow: [
            BoxShadow(
              color: Color(0x19006162),
              blurRadius: 32,
              offset: Offset(0, 4),
              spreadRadius: 0,
            )
          ]),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppImage(path: AppImagePaths.dataUsage),
                      SizedBox(width: 8),
                      Text(
                        isDataCapReached
                            ? 'daily_data_cap_reached'.i18n
                            : 'daily_data_usage'.i18n,
                        style: textTheme.labelLarge!.copyWith(
                          color: isDataCapReached
                              ? AppColors.red8
                              : AppColors.gray7,
                        ),
                      ),
                      Spacer(),
                      if (!isDataCapReached)
                        Text(
                          '$usageString${'mb'.i18n}',
                          style: textTheme.titleSmall!.copyWith(
                            color: AppColors.gray9,
                          ),
                        ),
                    ],
                  ),
                  if (isDataCapReached)
                    Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: AutoSizeText(
                        dataCapMessage,
                        minFontSize: 11,
                        maxFontSize: 12,
                        maxLines: 1,
                        style: textTheme.bodySmall!.copyWith(
                          color: AppColors.red8,
                        ),
                      ),
                    ),
                  SizedBox(height: 8),
                  Container(
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: isDataCapReached
                            ? BorderSide.none
                            : BorderSide(width: 1, color: AppColors.gray3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 400),
                      tween: Tween(begin: 0, end: newProgress),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) =>
                          LinearProgressIndicator(
                        value: value,
                        minHeight: 9,
                        borderRadius: const BorderRadius.all(
                            Radius.circular(defaultSize)),
                        trackGap: 10,
                        backgroundColor: AppColors.gray1,
                        valueColor: AlwaysStoppedAnimation(isDataCapReached
                            ? AppColors.red6
                            : AppColors.yellow3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  /// Formats the daily reset time based on whether it's today or another day.
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
}
