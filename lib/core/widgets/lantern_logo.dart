import 'package:flutter/material.dart';

import '../common/common.dart';

class LanternLogo extends StatelessWidget {
  final bool isPro;

  const LanternLogo({
    super.key,
    this.isPro = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppImage(
        path: isPro ? AppImagePaths.lanternPro : AppImagePaths.lanternLogo);
  }
}
