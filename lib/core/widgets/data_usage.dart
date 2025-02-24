import 'package:flutter/material.dart';

import '../common/common.dart';

class DataUsage extends StatelessWidget {
  const DataUsage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final remainingData = 300;
    final totalData = 500;
    final usageString = '$remainingData/$totalData';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                AppAsset(path: AppImagePaths.dataUsage),
                SizedBox(width: 8),
                Text(
                  'daily_data_usage'.i18n,
                  style: textTheme.labelLarge!.copyWith(
                    color: AppColors.gray7,
                  ),
                ),
                Spacer(),
                Text(usageString + ('mb'.i18n),
                    style: textTheme.titleSmall!.copyWith(
                      color: AppColors.gray9,
                    )),
              ],
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: (50.0 / 100).toDouble(),
              minHeight: 12,
              borderRadius:
                  const BorderRadius.all(Radius.circular(defaultSize)),
              trackGap: 10,
              backgroundColor: AppColors.gray1,
              valueColor: AlwaysStoppedAnimation(AppColors.yellow3),
            ),
          ],
        ),
      ),
    );
  }
}
