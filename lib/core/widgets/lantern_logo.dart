import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

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
    // Cap usable width to avoid tablets blowing up the logo
    final usableWidth = math.min(MediaQuery.sizeOf(context).width, 430.0);

    final rawWidth = (widthFraction ?? 0.27) * usableWidth;

    final width = math.min(rawWidth, 140.0);
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
