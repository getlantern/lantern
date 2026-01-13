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

    return dataCapAsync.when(
      data: (dataCapResponse) {
        /// If data cap is not enabled, don't show the widget
        if (!dataCapResponse.enabled || dataCapResponse.usage == null) {
          return const SizedBox.shrink();
        }
        final dataCap = dataCapResponse.usage!;

        /// Do all math in BYTES
        final int totalBytes = dataCap.bytesAllotted;
        final int usedBytes = dataCap.bytesUsed.clamp(0, totalBytes);
        final int remainingBytes = totalBytes - usedBytes;

        /// Convert to MB only for display
        final int totalData = (totalBytes.toMB).round();
        final int remainingData = (remainingBytes.toMB).round();
        final int usedData = (usedBytes.toMB).round();

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
                children: [
                  Row(
                    children: [
                      AppImage(path: AppImagePaths.dataUsage),
                      SizedBox(width: 8),
                      Text(
                        'daily_data_usage'.i18n,
                        style: textTheme.labelLarge!.copyWith(
                          color: AppColors.gray7,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '$usageString${'mb'.i18n}',
                        style: textTheme.titleSmall!.copyWith(
                          color: AppColors.gray9,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(width: 1, color: AppColors.gray3),
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
                        minHeight: 8,
                        borderRadius: const BorderRadius.all(
                            Radius.circular(defaultSize)),
                        trackGap: 10,
                        backgroundColor: AppColors.gray1,
                        valueColor: AlwaysStoppedAnimation(AppColors.yellow3),
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
