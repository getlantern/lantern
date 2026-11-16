import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';

/// A note in a bordered card: an icon and a line of text, or [child]. The
/// card grows with its text.
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

  /// A one-line note's height, as a list tile's.
  static const _defaultMinHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: BorderSide(color: borderColor ?? context.borderDefault),
    );
    return Material(
      color: backgroundColor ?? context.bgElevated,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minTileHeight ?? _defaultMinHeight,
          ),
          child: Padding(
            padding:
                padding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (showLeadingIcon) ...[
                  icon ?? AppImage(path: imagePath ?? AppImagePaths.info),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: textTheme.bodyLarge,
                    child:
                        child ??
                        Text(
                          text,
                          style:
                              textStyle ??
                              textTheme.bodyMedium!.copyWith(
                                color: context.textSecondary,
                              ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
