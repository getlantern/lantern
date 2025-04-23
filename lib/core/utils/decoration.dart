import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';

BoxDecoration get selectedDecoration {
  return BoxDecoration(
    color: AppColors.blue1,
    border: Border.all(color: AppColors.blue7, width: 3),
    borderRadius: BorderRadius.circular(16),
  );
}

BoxDecoration get unselectedDecoration {
  return BoxDecoration(
    color: AppColors.white,
    border: Border.all(color: AppColors.gray3, width: 1.5),
    borderRadius: BorderRadius.circular(16),
  );
}