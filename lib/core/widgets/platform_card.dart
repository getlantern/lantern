import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../common/common.dart';

class PlatformCard extends StatelessWidget {

  final String imagePath;
  final VoidCallback onPressed;
  const PlatformCard({super.key, required this.imagePath, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AppCard(
        padding: EdgeInsets.all(18.r),
        child: AppImage(path: imagePath),
      ),
    );
  }
}
