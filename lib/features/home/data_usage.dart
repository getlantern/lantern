import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/features/home/provider/data_cap_info_provider.dart';

import '../../core/common/common.dart';

class DataUsage extends ConsumerWidget {
  const DataUsage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final dataCapAsync = ref.watch(dataCapInfoNotifierProvider);

    int remainingData = 300;
    int totalData = 500;
    dataCapAsync.whenData((dataCap) {
      remainingData = (dataCap.bytesRemaining / (1024 * 1024)).round();
      totalData = (dataCap.bytesAllotted / (1024 * 1024)).round();
    });

    final usageString = '$remainingData/$totalData';

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
                  Text('$usageString${'mb'.i18n}',
                      style: textTheme.titleSmall!.copyWith(
                        color: AppColors.gray9,
                      )),
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
                child: LinearProgressIndicator(
                  value: totalData == 0
                      ? 0
                      : (1 - remainingData / totalData).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  borderRadius:
                      const BorderRadius.all(Radius.circular(defaultSize)),
                  trackGap: 10,
                  backgroundColor: AppColors.gray1,
                  valueColor: AlwaysStoppedAnimation(AppColors.yellow3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
