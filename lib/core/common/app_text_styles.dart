import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lantern/core/common/app_colors.dart';

///All Text styles based on figma design
///https://www.figma.com/design/JTguURC2QTtsi904f6mACo/Lantern-VPN-Design-System?node-id=2097-43525&t=QzbvtF1t2XIgQs7k-0

class AppTestStyles {
  static TextStyle get displayLarge => GoogleFonts.urbanist(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      );

  static TextStyle get displayMedium => GoogleFonts.urbanist(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      );

  static TextStyle get displaySmall => GoogleFonts.urbanist(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      );

  static TextStyle get headingLarge => GoogleFonts.urbanist(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      );

  static TextStyle get headingMedium => GoogleFonts.urbanist(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      );

  static TextStyle get headingSmall => GoogleFonts.urbanist(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      );

  static TextStyle get labelLarge => GoogleFonts.urbanist(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 26 / 16,
        letterSpacing: 0,
        color: AppColors.black,
      );

  static TextStyle get labelMedium => GoogleFonts.urbanist(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.black,
      );

  static TextStyle get labelSmall => GoogleFonts.urbanist(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.black,
      );

  static TextStyle get titleLarge => GoogleFonts.urbanist(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      );

  static TextStyle get titleMedium => GoogleFonts.urbanist(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      );

  static TextStyle get titleSmall => GoogleFonts.urbanist(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      );

  static TextStyle get bodyLarge => GoogleFonts.urbanist(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.black,
      );

  static TextStyle get bodyMedium => GoogleFonts.urbanist(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.black,
      );

  static TextStyle get bodySmall => GoogleFonts.urbanist(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.black,
      );

  //Text style for button

  static TextStyle get primaryButtonTextStyle => GoogleFonts.urbanist(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.white,
      );

  // Text style for logs
  static TextStyle get logTextStyle => GoogleFonts.ibmPlexMono(
        color: Color(0xFFDEDFDF),
        fontSize: 10,
        fontWeight: FontWeight.w400,
        height: 1.30,
      );
}
