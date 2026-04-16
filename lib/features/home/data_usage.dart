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
    final dataCapNotifier = ref.read(dataCapInfoProvider.notifier);
    return dataCapAsync.when(
      data: (dataCapResponse) {
        /// If data cap is not enabled, don't show the widget
        if (!dataCapResponse.enabled || dataCapResponse.usage == null) {
          return const SizedBox.shrink();
        }
        final dataCap = dataCapResponse.usage!;

        /// Do all math in BYTES
        final int totalBytes = max(0, dataCap.bytesAllotted);
        if (totalBytes == 0) {
          appLogger.warning(
            'Data cap enabled but bytesAllotted is 0; hiding data usage card to avoid false cap reached UI',
          );
          return const SizedBox.shrink();
        }
        final int usedBytes = dataCap.bytesUsed.clamp(0, totalBytes);
        final int remainingBytes = totalBytes - usedBytes;
        final isDataCapReached = usedBytes >= totalBytes;
        appLogger.debug(
          "Data Usage - Bytes: $totalBytes bytes, Used: $usedBytes bytes, Remaining: $remainingBytes bytes",
        );
        final dataCapResetTime = dataCapNotifier.formatDailyResetTime(
          dataCap.allotmentEndTime,
        );
        String dataCapMessage = "daily_data_cap_reached_message".i18n.fill([
          dataCapResetTime,
        ]);

        ///If parsing fails and returns empty string
        ///do not show time
        if (dataCapResetTime.isEmpty) {
          dataCapMessage = dataCapMessage.split('-').first;
        }

        /// Convert to MB only for display
        final int totalData = (totalBytes.toMB).round();
        final int remainingData = (remainingBytes.toMB).round();
        final int usedData = usedBytes == 0
            ? 0
            : max(1, usedBytes.toMB.round());
        appLogger.debug(
          "Data Usage - Total: $totalData MB, Used: $usedData MB, Remaining: $remainingData MB",
        );

        final usageString = '$usedData/$totalData';

        final newProgress = (usedBytes / totalBytes).clamp(0.0, 1.0);

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x19006162),
                blurRadius: 32,
                offset: Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
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
                              ? context.statusErrorText
                              : context.textTertiary,
                        ),
                      ),
                      Spacer(),
                      if (!isDataCapReached)
                        Text(
                          '$usageString${'mb'.i18n}',
                          style: textTheme.titleSmall!.copyWith(
                            color: context.textPrimary,
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
                          color: context.statusErrorText,
                        ),
                      ),
                    ),
                  SizedBox(height: 8),
                  Container(
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: isDataCapReached
                            ? BorderSide.none
                            : BorderSide(width: 1, color: context.borderInput),
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
                              Radius.circular(defaultSize),
                            ),
                            trackGap: 10,
                            backgroundColor: context.bgSurface,
                            valueColor: AlwaysStoppedAnimation(
                              isDataCapReached
                                  ? context.statusErrorBgDot
                                  : AppColors.yellow3,
                            ),
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
}
