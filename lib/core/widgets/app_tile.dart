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
  final double? minHeight;
  final TextStyle? tileTextStyle;
  final bool selected;

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
    this.minHeight,
    this.selected = false,
  });

  factory AppTile.link({
    required Object icon,
    required String label,
    required String url,
    EdgeInsets? contentPadding,
    Widget? subtitle,
  }) =>
      AppTile(
        icon: icon,
        label: label,
        subtitle: subtitle,
        onPressed: () => UrlUtils.openWithSystemBrowser(url),
        trailing: AppImage(path: AppImagePaths.outsideBrowser),
        contentPadding: contentPadding,
      );

  @override
  Widget build(BuildContext context) {
    final isDoubleLine = subtitle != null;
    final effectiveMinHeight = isDoubleLine ? 72.0 : minHeight;

    final textStyle = tileTextStyle ??
        Theme.of(context).textTheme.labelLarge!.copyWith(
              color: AppColors.gray9,
              fontWeight: FontWeight.w400,
              fontSize: 16,
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
      selected: selected,
      selectedTileColor: AppColors.blue1,
      minTileHeight: effectiveMinHeight,
      contentPadding:
          contentPadding ?? const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label,
          style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle,
      dense: dense,
      leading: leading,
      trailing: trailing,
      onTap: onPressed,
      horizontalTitleGap: 12,
      visualDensity: VisualDensity.standard,
    );
  }
}
