import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_colors.dart';

class Spinner extends StatelessWidget {
  const Spinner({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 8.r,
        //strokeWidth: 4.0,
        color: AppColors.logTextColor,
      ),
    );
  }
}
