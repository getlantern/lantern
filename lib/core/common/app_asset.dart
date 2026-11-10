import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/widgets/app_focusable.dart';

export 'package:flutter_svg/flutter_svg.dart';

enum AssetType { svg, png }

class AppImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final Color? color;
  final AssetType type;
  final OnPressed? onPressed;
  final BoxFit? fit;
  // Set to false for decorative/multicolor assets (illustrations, logos)
  // that should not be recolored by the theme.
  final bool useThemeColor;

  const AppImage({
    required this.path,
    this.width,
    this.height,
    this.color,
    this.type = AssetType.svg,
    this.onPressed,
    this.fit,
    this.useThemeColor = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final image = switch (type) {
      AssetType.svg => SvgPicture.asset(
        path,
        height: height,
        width: width,
        fit: fit ?? BoxFit.contain,
        // Use explicit color > theme icon color > no filter (when opted out)
        colorFilter: switch (color ??
            (useThemeColor ? Theme.of(context).iconTheme.color : null)) {
          final c? => ColorFilter.mode(c, BlendMode.srcIn),
          null => null,
        },
      ),
      AssetType.png => Image.asset(
        path,
        color: color,
        height: height,
        width: width,
        fit: fit ?? BoxFit.cover,
      ),
    };
    if (onPressed == null) return image;
    return AppFocusable(
      onActivate: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: image,
    );
  }
}
