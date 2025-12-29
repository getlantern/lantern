import 'package:flutter/material.dart';

import '../common/common.dart';

typedef LinkOpener = Future<void> Function(String url);

class AppTile extends StatelessWidget {
  final String label;
  final Widget? subtitle;

  final Object? icon;
  final Widget? trailing;

  // Actions
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool loading;
  final bool selected;
  final bool showChevron;

  final EdgeInsets? contentPadding;
  final bool? dense;
  final double? minHeight;
  final TextStyle? tileTextStyle;
  final String? tooltip;
  final String? semanticsLabel;

  final Color? tileColor;
  final Color? hoverColor;
  final Color? selectedTileColor;
  final BorderRadius? borderRadius;
  final VisualDensity? visualDensity;

  const AppTile({
    super.key,
    required this.label,
    this.onPressed,
    this.onLongPress,
    this.icon,
    this.subtitle,
    this.trailing,
    this.contentPadding,
    this.tileTextStyle,
    this.dense,
    this.minHeight,
    this.enabled = true,
    this.loading = false,
    this.selected = false,
    this.showChevron = false,
    this.tooltip,
    this.semanticsLabel,
    this.tileColor,
    this.hoverColor,
    this.selectedTileColor,
    this.borderRadius,
    this.visualDensity,
  });

  factory AppTile.link({
    required Object icon,
    required String label,
    required String url,
    EdgeInsets? contentPadding,
    Widget? subtitle,
    LinkOpener? open,
    bool externalIndicator = true,
    String? tooltip,
  }) {
    return AppTile(
      icon: icon,
      label: label,
      subtitle: subtitle,
      onPressed: () => (open ?? UrlUtils.openWithSystemBrowser)(url),
      trailing: externalIndicator
          ? AppImage(path: AppImagePaths.outsideBrowser)
          : null,
      contentPadding: contentPadding,
      tooltip: tooltip ?? url,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDoubleLine = subtitle != null;
    final effectiveMinHeight = isDoubleLine ? 72.0 : (minHeight ?? 56.0);

    final textStyle = tileTextStyle ??
        theme.textTheme.labelLarge!.copyWith(
          color: enabled ? AppColors.gray9 : AppColors.gray6,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        );

    Widget? computedLeading;
    if (icon != null) {
      if (icon is String) {
        computedLeading = SizedBox(
          width: 24,
          height: 24,
          child: AppImage(path: icon as String),
        );
      } else if (icon is IconData) {
        computedLeading =
            Icon(icon as IconData, size: 24, color: AppColors.gray9);
      } else if (icon is Image) {
        computedLeading = icon as Image;
      } else if (icon is Widget) {
        computedLeading = icon as Widget;
      }
    }

    Widget? computedTrailing = loading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2))
        : trailing ?? (showChevron ? const Icon(Icons.chevron_right) : null);

    final tile = ListTile(
      enabled: enabled && !loading,
      minVerticalPadding: 0,
      selected: selected,
      titleAlignment: ListTileTitleAlignment.center,
      hoverColor: hoverColor ?? AppColors.blue1,
      selectedTileColor: selectedTileColor ?? AppColors.blue1,
      tileColor: tileColor,
      minTileHeight: minHeight ?? effectiveMinHeight,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
      ),
      contentPadding:
          contentPadding ?? const EdgeInsets.symmetric(horizontal: 16),
      title: Text(
        label,
        style: textStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle,
      dense: dense,
      leading: computedLeading,
      trailing: computedTrailing,
      onTap: enabled && !loading ? onPressed : null,
      onLongPress: enabled && !loading ? onLongPress : null,
      horizontalTitleGap: 12,
      visualDensity: visualDensity ?? VisualDensity.standard,
    );

    final wrapped =
        tooltip != null ? Tooltip(message: tooltip!, child: tile) : tile;

    return Semantics(
      label: semanticsLabel ?? 'Tile: $label',
      button: onPressed != null,
      enabled: enabled,
      selected: selected,
      child: wrapped,
    );
  }
}
