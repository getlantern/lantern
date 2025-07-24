import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../common/common.dart';

class LanternLogo extends StatelessWidget {
  final bool isPro;
  final Color? color;
  final double? height;
  final double? widthFraction;

  const LanternLogo({
    super.key,
    this.isPro = false,
    this.color,
    this.height,
    this.widthFraction = 0.27,
  });

  @override
  Widget build(BuildContext context) {
    final aspectRatio = 105.64 / 20;
    final screenWidth = 1.sw;
    final width = (widthFraction ?? (105.64 / 390)) * screenWidth;
    final height = width / aspectRatio;

    return AppImage(
      path: isPro ? AppImagePaths.lanternPro : AppImagePaths.lanternLogo,
      color: color ?? AppColors.blue10,
      height: height,
      width: width,
      fit: BoxFit.contain,
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
