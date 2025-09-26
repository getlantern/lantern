import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/common/common.dart';

class AppVersion extends StatelessWidget {
  const AppVersion({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return FutureBuilder<String>(
      future: resolveAppVersionLabel(),
      builder: (context, snap) {
        final label = snap.data ?? '…';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.gray1,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              top: BorderSide(color: AppColors.gray2, width: 1),
              bottom: BorderSide(color: AppColors.gray2, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('lantern_version'.i18n, style: theme.bodyMedium),
              Text(label,
                  style: theme.titleSmall!.copyWith(color: AppColors.blue7)),
            ],
          ),
        );
      },
    );
  }
}
