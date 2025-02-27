import 'package:flutter/material.dart';
import 'package:lantern/core/utils/url_utils.dart';

import '../common/common.dart';

class AppTile extends StatelessWidget {
  final String label;
  final Object? icon;
  final Widget? trailing;
  final Widget? subtitle;
  final VoidCallback? onPressed;
  final EdgeInsets? contentPadding;

  const AppTile({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.subtitle,
    this.trailing,
    this.contentPadding,
  });

  factory AppTile.link({
    required Object icon,
    required String label,
    required String url,
    EdgeInsets? contentPadding,
  }) =>
      AppTile(
        icon: icon,
        label: label,
        onPressed: () => openUrl(url),
        trailing: AppAsset(path: AppImagePaths.outsideBrowser),
        contentPadding: contentPadding,
      );

  @override
  Widget build(BuildContext context) {
    final tileTextStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
          color: AppColors.gray9,
        );

    Widget? leading;
    if (icon != null) {
      if (icon is String) {
        leading = SizedBox(
          width: 24,
          height: 24,
          child: AppAsset(path: icon as String),
        );
      } else if (icon is IconData) {
        leading = Icon(
          icon as IconData,
          size: 24,
          color: AppColors.gray9,
        );
      }
    }

    return ListTile(
      enableFeedback: true,
      minVerticalPadding: 0,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label, style: tileTextStyle),
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: onPressed,
    );
  }
}
