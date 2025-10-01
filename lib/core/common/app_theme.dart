import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lantern/core/common/app_text_styles.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData appTheme() {
    return ThemeData(
      useMaterial3: true,
      hoverColor: AppColors.blue1,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.blue10,
        selectionColor: AppColors.blue6,
        selectionHandleColor: AppColors.blue7,
      ),
      textTheme: GoogleFonts.urbanistTextTheme().copyWith(
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        displaySmall: AppTextStyles.displaySmall,
        headlineLarge: AppTextStyles.headingLarge,
        headlineMedium: AppTextStyles.headingMedium,
        headlineSmall: AppTextStyles.headingSmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: AppTextStyles.titleSmall,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        surfaceTintColor: AppColors.white,
        titleTextStyle: AppTextStyles.headingSmall.copyWith(
          color: AppColors.blue10,
        ),
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: AppColors.gray1,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.white,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.gray1,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        iconTheme: IconThemeData(
          color: AppColors.blue10,
        ),
      ),
      primaryColor: AppColors.blue10,
      scaffoldBackgroundColor: AppColors.gray1,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.white,
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(
            color: AppColors.gray2,
            width: 1,
          ),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(AppColors.gray9),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        splashRadius: 10.0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.blue10,
          enableFeedback: true,
          foregroundColor: AppColors.gray1,
          textStyle: AppTextStyles.primaryButtonTextStyle
              .copyWith(fontSize: 18.0, color: AppColors.gray1),
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
