import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/common/app_text_styles.dart';

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
    Key? key,
    this.icon,
    required this.text,
    this.textStyle,
    this.backgroundColor,
    this.imagePath,
    this.borderRadius = 8,
    this.padding,
    this.onPressed,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // final child = Row(
    //   crossAxisAlignment: CrossAxisAlignment.center,
    //   children: [
    //     if (icon != null) icon!,
    //     const SizedBox(width: 8),
    //     Expanded(
    //       child: Text(
    //         text,
    //         style: textStyle ??
    //             Theme.of(context)
    //                 .textTheme
    //                 .bodyMedium!
    //                 .copyWith(color: AppColors.gray8),
    //       ),
    //     ),
    //   ],
    // );
    return Material(
      color: backgroundColor ?? AppColors.gray1,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding ??
              const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: child ??
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: AppImage(
                      path: imagePath ?? AppImagePaths.info,
                      width: 20,
                      height: 20,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTestStyles.bodyMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.43,
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }
}
