import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';

class AppVersion extends StatelessWidget {
  final String version;

  const AppVersion({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gray1,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          top: BorderSide(
            color: AppColors.gray2,
            width: 1,
          ),
          bottom: BorderSide(
            color: AppColors.gray2,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Lantern Version',
            style: theme.bodyMedium,
          ),
          Text(
            version,
            style: theme.titleSmall!.copyWith(
              color: AppColors.blue7,
            ),
          ),
        ],
      ),
    );
  }
}
