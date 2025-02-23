import 'package:flutter/material.dart';
import 'package:lantern/core/utils/url_utils.dart';

import '../common/common.dart';

class AppTile extends StatelessWidget {
  final String label;
  final Object? icon;
  final Widget? trailing;
  final Widget? subtitle;
  final VoidCallback? onPressed;
  final EdgeInsets? dividerPadding;
  final double? tileWidth;
  final double? tileHeight;

  const AppTile({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.subtitle,
    this.trailing,
    this.dividerPadding,
    this.tileWidth,
    this.tileHeight,
  });

  factory AppTile.link({
    required Object icon,
    required String label,
    required String url,
    double? tileHeight,
    EdgeInsets? dividerPadding,
  }) =>
      AppTile(
        icon: icon,
        label: label,
        onPressed: () => openUrl(url),
        trailing: AppAsset(path: AppImagePaths.outsideBrowser),
        dividerPadding: dividerPadding,
        tileHeight: tileHeight ?? 56,
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

    final tileWidget = Container(
      height: tileHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        enableFeedback: true,
        horizontalTitleGap: 16,
        minVerticalPadding: 0,
        contentPadding: EdgeInsets.zero,
        title: Text(
          label,
          style: tileTextStyle,
        ),
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        onTap: onPressed,
      ),
    );

    if (dividerPadding != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tileWidget,
          Padding(
            padding: dividerPadding!,
            child: DividerSpace(),
          ),
        ],
      );
    }
    return tileWidget;
  }
}
