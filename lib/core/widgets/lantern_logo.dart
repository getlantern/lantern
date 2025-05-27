import 'package:flutter/material.dart';

import '../common/common.dart';

class LanternLogo extends StatelessWidget {
  final bool isPro;
  final Color? color;

  const LanternLogo({
    super.key,
    this.isPro = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppImage(
      path: isPro ? AppImagePaths.lanternPro : AppImagePaths.lanternLogo,
      color: color ?? AppColors.blue10,
      height: 25,
    );
  }
}

class LanternRoundedLogo extends StatelessWidget {
  final double? height;
  final double? width;
  const LanternRoundedLogo({
    super.key,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return AppImage(
      height: height,
      width: width,
      path: AppImagePaths.lanternLogoRounded,
    );
  }
}
