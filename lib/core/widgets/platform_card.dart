import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../common/common.dart';

class PlatformCard extends StatelessWidget {
  final String imagePath;
  final VoidCallback onPressed;

  const PlatformCard(
      {super.key, required this.imagePath, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      hoverColor: AppColors.blue1,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          padding: EdgeInsets.all(15.r),
          backgroundColor: AppColors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: AppImage(
          fit: BoxFit.contain,
          path: imagePath,
          height: 32,
          width: 32,
        ));
  }
}
