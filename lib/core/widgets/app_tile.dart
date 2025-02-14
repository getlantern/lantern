import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';

class AppTile extends StatelessWidget {
  final String label;

  final String icon;

  final VoidCallback onPressed;

  const AppTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme.labelLarge!;
    return ListTile(
      title: Text(
        label,
        style: theme.copyWith(
          color: AppColors.blue10,
          fontSize: 18.0
        ),
      ),
      leading: AppAsset(path: icon),
      onTap: onPressed,
    );
  }
}
