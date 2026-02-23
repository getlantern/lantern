import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';

class InfoRow extends StatelessWidget {
  final Widget? icon;
  final String text;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? borderColor;
  final Widget? child;
  final double borderRadius;
  final String? imagePath;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onPressed;
  final double? minTileHeight;
  final bool showLeadingIcon;

  const InfoRow({
    super.key,
    this.icon,
    required this.text,
    this.textStyle,
    this.backgroundColor,
    this.borderColor,
    this.imagePath,
    this.borderRadius = 8,
    this.padding,
    this.onPressed,
    this.child,
    this.minTileHeight,
    this.showLeadingIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
        minTileHeight: minTileHeight,
        tileColor: backgroundColor?? context.bgElevated,
        onTap: onPressed,
        contentPadding:
            padding ?? EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: borderColor ?? context.borderDefault),
        ),
        leading: showLeadingIcon
            ? AppImage(
                path: imagePath ?? AppImagePaths.info,
              )
            : null,
        title: child ??
            Text(
              text,
              style: textStyle ??
                  (textTheme.bodyMedium)!.copyWith(
                    color: context.textSecondary,
                  ),
            ));
  }
}
