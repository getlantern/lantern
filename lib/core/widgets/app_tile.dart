import 'package:flutter/material.dart';

import '../common/common.dart';


class AppTile extends StatelessWidget {
  final String label;

  final String? icon;
  final Widget? trailing;
  final Widget? subtitle;

  final VoidCallback onPressed;

  const AppTile({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme
        .of(context)
        .textTheme
        .labelLarge!;
    return ListTile(
      enableFeedback: true,
      minVerticalPadding: 0,
      title: Text(
        label,
        style: theme.copyWith(color: AppColors.gray9, fontSize: font16),
      ),
      subtitle:subtitle,
      leading: icon != null ? AppAsset(path: icon!) :null,
      trailing: trailing,
      onTap: onPressed,
    );
  }
}
