import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_image_paths.dart';

class InfoRow extends StatelessWidget {
  final Widget? icon;
  final String text;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Widget? child;
  final double borderRadius;
  final String? imagePath;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onPressed;

  const InfoRow({
    super.key,
    this.icon,
    required this.text,
    this.textStyle,
    this.backgroundColor,
    this.imagePath,
    this.borderRadius = 8,
    this.padding,
    this.onPressed,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
        tileColor: backgroundColor,
        onTap: onPressed,
        contentPadding:
            padding ?? EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: BorderSide(color: AppColors.gray2),
        ),
        leading: imagePath == null
            ? null
            : AppImage(
                path: imagePath ?? AppImagePaths.info,
              ),
        title: child ??
            Text(
              text,
              style: (textStyle ?? textTheme.bodyMedium)!.copyWith(
                color: AppColors.gray8,
              ),
            ));
  }
}
