import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lantern/core/common/app_buttons.dart';

export 'package:flutter_svg/flutter_svg.dart';

enum AssetType {
  svg,
  png,
}

class AppImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final Color? color;
  final AssetType type;
  final OnPressed? onPressed;
  final BoxFit? fit;

  const AppImage({
    required this.path,
    this.width,
    this.height,
    this.color,
    this.type = AssetType.svg,
    this.onPressed,
    this.fit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case AssetType.svg:
        return GestureDetector(
          onTap: onPressed,
          child: SvgPicture.asset(
            path,
            height: height,
            width: width,
            fit: fit ?? BoxFit.contain,
            colorFilter: color != null
                ? ColorFilter.mode(color!, BlendMode.srcIn)
                : null,
          ),
        );
      case AssetType.png:
        return GestureDetector(
          onTap: onPressed,
          child: Image.asset(
            path,
            color: color,
            height: height,
            width: width,
            fit: fit ?? BoxFit.cover,
          ),
        );
    }
  }
}
