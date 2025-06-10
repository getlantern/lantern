import 'package:flutter/material.dart';

import '../common/common.dart';

class AppTile extends StatelessWidget {
  final String label;
  final Object? icon;
  final Widget? trailing;
  final Widget? subtitle;
  final VoidCallback? onPressed;
  final EdgeInsets? contentPadding;
  final bool? dense;

  final TextStyle? tileTextStyle;

  const AppTile({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.subtitle,
    this.trailing,
    this.contentPadding,
    this.tileTextStyle,
    this.dense,
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
        onPressed: () => UrlUtils.openWithSystemBrowser(url),
        trailing: AppImage(path: AppImagePaths.outsideBrowser),
        contentPadding: contentPadding,
      );

  @override
  Widget build(BuildContext context) {
    final _tileTextStyle = tileTextStyle ??
        Theme.of(context).textTheme.labelLarge!.copyWith(
              color: AppColors.gray9,
            );

    Widget? leading;
    if (icon != null) {
      if (icon is String) {
        leading = SizedBox(
          width: 24,
          height: 24,
          child: AppImage(path: icon as String),
        );
      } else if (icon is IconData) {
        leading = Icon(
          icon as IconData,
          size: 24,
          color: AppColors.gray9,
        );
      } else if (icon is Image) {
        leading = icon as Image;
      } else if (icon is Widget) {
        leading = icon as Widget;
      }
    }

    return ListTile(
      enableFeedback: true,
      minVerticalPadding: 0,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label, style: _tileTextStyle),
      subtitle: subtitle,
      dense: dense,
      leading: leading,
      trailing: trailing,
      onTap: onPressed,
    );
  }
}
