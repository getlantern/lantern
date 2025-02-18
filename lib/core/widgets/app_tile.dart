import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';

class AppTile extends StatelessWidget {
  final String label;

  final String icon;
  final Widget? trailing;

  final VoidCallback onPressed;

  const AppTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme.labelLarge!;
    return ListTile(
      title: Text(
        label,
        style: theme.copyWith(color: AppColors.gray9, fontSize: 18.0),
      ),
      leading: AppAsset(path: icon),
      trailing: trailing,
      onTap: onPressed,
    );
  }
}
