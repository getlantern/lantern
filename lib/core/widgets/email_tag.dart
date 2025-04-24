import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../common/common.dart';

class EmailTag extends StatelessWidget {
  final String email;

  const EmailTag({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Chip(
      color: WidgetStatePropertyAll(AppColors.blue1),
      elevation: 0,
      avatar: AppImage(
        path: AppImagePaths.email,
        height: 20.h,
      ),
      padding: const EdgeInsets.symmetric(horizontal: defaultSize, vertical: 8),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 14,
          ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(100),
        side: BorderSide(
          color: AppColors.gray3,
          width: 1,
        ),
      ),
      label: Text(email),
    );
  }
}
