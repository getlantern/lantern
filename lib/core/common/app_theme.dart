import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lantern/core/common/app_text_styles.dart';

import 'app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Figma token → ColorScheme slot reference
//
// token                 light           dark
// ─────────────────────────────────────────────────────────────────────────────
// bg.elevated           white           gray850          → surface
// bg.surface            gray1           gray9            → surfaceContainer
// bg.callout            gray2           gray8            → surfaceContainerHighest
// bg.hover              blue1           blue9            → primaryContainer
// text.primary          gray9           gray2            → onSurface
// text.secondary        gray8           gray3            → onSurfaceVariant
// text.link             blue8(≈blue7)   blue2            → primary (textButtonTheme)
// border.default        gray2           gray8            → outline
// border.input          gray3           gray7            → outlineVariant
// border.input-focus    blue8           blue2            → primary (focused border)
// border.error          red6            red5             → error
// status.error-bg       red2            red8             → errorContainer
// status.error-text     red8            red2             → onErrorContainer
// action.primary.bg     blue10          blue6            → primary (elevatedButton)
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  // ── Light ──────────────────────────────────────────────────────────────────

  static ThemeData appTheme() {
    const cs = ColorScheme.light(
      // Primary action / brand
      primary: AppColors.blue10,                   // Blue.1000 – action.primary.bg
      onPrimary: AppColors.gray1,                  // Gray.100  – action.primary.text
      primaryContainer: AppColors.blue1,           // Blue.100  – bg.hover
      onPrimaryContainer: AppColors.gray9,
      // Secondary
      secondary: AppColors.blue7,                  // Blue.700
      onSecondary: AppColors.gray1,
      secondaryContainer: AppColors.blue2,         // Blue.200
      onSecondaryContainer: AppColors.gray9,
      // Success (tertiary)
      tertiary: AppColors.green5,                  // Green.500 – toggle-active-bg
      onTertiary: AppColors.gray1,
      tertiaryContainer: AppColors.green2,         // Green.200 – status.success-bg
      onTertiaryContainer: AppColors.green8,       // Green.800 – status.success-text
      // Error
      error: AppColors.red6,                       // Red.600  – border.error
      onError: AppColors.gray1,
      errorContainer: AppColors.red2,              // Red.200  – status.error-bg
      onErrorContainer: AppColors.red8,            // Red.800  – status.error-text
      // Surfaces
      surface: AppColors.white,                    // White     – bg.elevated (Card, Dialog, Sheet)
      onSurface: AppColors.gray9,                  // Gray.900  – text.primary
      onSurfaceVariant: AppColors.gray8,           // Gray.800  – text.secondary
      surfaceContainer: AppColors.gray1,           // Gray.100  – bg.surface
      surfaceContainerHighest: AppColors.gray2,    // Gray.200 – bg.callout
      // Borders
      outline: AppColors.gray2,                    // Gray.200  – border.default
      outlineVariant: AppColors.gray3,             // Gray.300  – border.input
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      hoverColor: AppColors.blue1,
      scaffoldBackgroundColor: AppColors.gray1,   // bg.surface
      primaryColor: AppColors.blue10,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),

      // ── Text ────────────────────────────────────────────────────────────────
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

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: true,
        surfaceTintColor: AppColors.white,
        titleTextStyle: AppTextStyles.headingSmall.copyWith(
          color: AppColors.blue10,
        ),
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: AppColors.gray1,          // bg.surface
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.white,
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.gray1,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        iconTheme: IconThemeData(color: AppColors.blue10),
      ),

      // ── Card ────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.surface,                         // bg.elevated
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: cs.outline, width: 1), // border.default
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: cs.outline,                         // border.default
        thickness: 1,
      ),

      // ── Input / TextField ────────────────────────────────────────────────────
      // Widgets using TextFormField / TextField inherit these automatically.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,                     // bg.input = bg.elevated
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        hintStyle: TextStyle(color: AppColors.gray4),
        labelStyle: TextStyle(color: cs.onSurfaceVariant), // text.secondary
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant), // border.input
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.blue8, width: 2), // border.input-focus
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.error),           // border.error
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
      ),

      // ── Dialog ──────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,              // bg.elevated
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant, width: 1),
        ),
        titleTextStyle: AppTextStyles.headingSmall,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),

      // ── Bottom Sheet ─────────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,              // bg.elevated
        modalBackgroundColor: cs.surface,
        dragHandleColor: AppColors.gray4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // ── ListTile (used by AppTile) ───────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        textColor: cs.onSurface,                  // text.primary
        iconColor: cs.onSurface,
        selectedColor: cs.primary,
        selectedTileColor: cs.primaryContainer,   // bg.hover
      ),

      // ── TextButton (used by AppTextButton) ───────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue7,        // text.link light
        ),
      ),

      // ── Radio ───────────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(cs.onSurface),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        splashRadius: 10.0,
      ),

      // ── ElevatedButton (PrimaryButton) ───────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: cs.primary,            // action.primary.primary-bg
          enableFeedback: true,
          foregroundColor: cs.onPrimary,          // action.primary.primary-text
          textStyle: AppTextStyles.primaryButtonTextStyle
              .copyWith(fontSize: 18.0, color: cs.onPrimary),
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

  // ── Dark ───────────────────────────────────────────────────────────────────

  static ThemeData darkTheme() {
    const cs = ColorScheme.dark(
      // Primary action / brand
      primary: AppColors.blue6,                    // Blue.600  – action.primary.bg
      onPrimary: AppColors.gray1,                  // Gray.100  – action.primary.text
      primaryContainer: AppColors.blue9,           // Blue.900  – bg.hover
      onPrimaryContainer: AppColors.gray2,
      // Secondary
      secondary: AppColors.blue5,                  // Blue.500
      onSecondary: AppColors.gray1,
      secondaryContainer: AppColors.blue7,         // Blue.700
      onSecondaryContainer: AppColors.gray2,
      // Success (tertiary)
      tertiary: AppColors.green7,                  // Green.700 – toggle-active-bg dark
      onTertiary: AppColors.gray1,
      tertiaryContainer: AppColors.green7,
      onTertiaryContainer: AppColors.green3,       // Green.300 – status.success-text dark
      // Error
      error: AppColors.red5,                       // Red.500   – border.error dark
      onError: AppColors.gray1,
      errorContainer: AppColors.red8,              // Red.800   – status.error-bg dark
      onErrorContainer: AppColors.red2,            // Red.200   – status.error-text dark
      // Surfaces
      surface: AppColors.gray850,                  // Gray.850  – bg.elevated (Card, Dialog, Sheet)
      onSurface: AppColors.gray2,                  // Gray.200  – text.primary dark
      onSurfaceVariant: AppColors.gray3,           // Gray.300  – text.secondary dark
      surfaceContainer: AppColors.gray9,           // Gray.900  – bg.surface dark
      surfaceContainerHighest: AppColors.gray8,    // Gray.800 – bg.callout dark
      // Borders
      outline: AppColors.gray8,                    // Gray.800  – border.default dark
      outlineVariant: AppColors.gray7,             // Gray.700  – border.input dark
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      hoverColor: AppColors.blue9,
      scaffoldBackgroundColor: AppColors.gray9,   // bg.surface dark
      primaryColor: AppColors.blue6,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),

      // ── Text ────────────────────────────────────────────────────────────────
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.blue6,
        selectionColor: AppColors.blue7,
        selectionHandleColor: AppColors.blue5,
      ),
      textTheme: GoogleFonts.urbanistTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).copyWith(
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

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: true,
        surfaceTintColor: AppColors.gray850,
        titleTextStyle: AppTextStyles.headingSmall.copyWith(
          color: cs.onSurface,                     // text.primary dark
        ),
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: AppColors.gray9,           // bg.surface dark
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.gray9,
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.gray9,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        iconTheme: IconThemeData(color: cs.onSurface),
      ),

      // ── Card ────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cs.surface,                          // bg.elevated dark
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: BorderSide(color: cs.outline, width: 1), // border.default dark
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: cs.outline,                          // border.default dark
        thickness: 1,
      ),

      // ── Input / TextField ────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,                      // bg.input dark (gray850)
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        hintStyle: TextStyle(color: AppColors.gray5), // text.disabled dark
        labelStyle: TextStyle(color: cs.onSurfaceVariant), // text.secondary dark
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant), // border.input dark
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.blue2, width: 2), // border.input-focus dark
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.error),            // border.error dark
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
      ),

      // ── Dialog ──────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,               // bg.elevated dark
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant, width: 1),
        ),
        titleTextStyle: AppTextStyles.headingSmall,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),

      // ── Bottom Sheet ─────────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,               // bg.elevated dark
        modalBackgroundColor: cs.surface,
        dragHandleColor: AppColors.gray6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // ── ListTile (used by AppTile) ───────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        textColor: cs.onSurface,                   // text.primary dark
        iconColor: cs.onSurface,
        selectedColor: cs.primary,
        selectedTileColor: cs.primaryContainer,    // bg.hover dark
      ),

      // ── TextButton (used by AppTextButton) ───────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue2,         // text.link dark
        ),
      ),

      // ── Radio ───────────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStatePropertyAll(cs.onSurface),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        splashRadius: 10.0,
      ),

      // ── ElevatedButton (PrimaryButton) ───────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: cs.primary,             // action.primary.primary-bg dark
          enableFeedback: true,
          foregroundColor: cs.onPrimary,            // action.primary.primary-text
          textStyle: AppTextStyles.primaryButtonTextStyle
              .copyWith(fontSize: 18.0, color: cs.onPrimary),
          overlayColor: AppColors.blue5,            // action.primary.primary-bg-hover dark
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
}
