import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData appTheme() {
    return ThemeData(
      useMaterial3: true,
      textTheme: TextTheme(
        bodyLarge: AppTestStyles.bodyLarge,
        bodyMedium: AppTestStyles.bodyMedium,
        bodySmall: AppTestStyles.bodySmall,
        displayLarge: AppTestStyles.displayLarge,
        displayMedium: AppTestStyles.displayMedium,
        displaySmall: AppTestStyles.displaySmall,
        headlineLarge: AppTestStyles.headingLarge,
        headlineMedium: AppTestStyles.headingMedium,
        headlineSmall: AppTestStyles.headingSmall,
        labelLarge: AppTestStyles.labelLarge,
        labelMedium: AppTestStyles.labelMedium,
        labelSmall: AppTestStyles.labelSmall,
        titleLarge: AppTestStyles.titleLarge,
        titleMedium: AppTestStyles.titleMedium,
        titleSmall: AppTestStyles.titleSmall,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        surfaceTintColor: AppColors.blue10,
        titleTextStyle: AppTestStyles.headingSmall.copyWith(
          color: AppColors.blue10,
        ),
        iconTheme: IconThemeData(
          color: AppColors.blue10,
        ),
      ),
      primaryColor: AppColors.blue10,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.blue10,
          enableFeedback: true,
          foregroundColor: Colors.white,
          textStyle: AppTestStyles.primaryButtonTextStyle.copyWith(fontSize: 18.0),
          overlayColor: AppColors.blue6,
          minimumSize: const Size(double.infinity, 52),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32.0),
            side: BorderSide.none,
          ),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData();
  }
}
