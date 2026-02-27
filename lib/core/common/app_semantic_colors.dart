import 'package:flutter/material.dart';
import 'app_colors.dart';

/// BuildContext extension that maps Figma Color/Semantic tokens to AppColors.
/// Every property has a light and dark value derived directly from the JSON export.
///
/// Usage:  context.textPrimary, context.bgElevated, context.borderInput …
extension AppSemanticColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Text ────────────────────────────────────────────────────────────────────

  /// text.primary  Gray.900 light / Gray.200 dark
  Color get textPrimary => isDark ? AppColors.gray2 : AppColors.gray9;

  /// text.secondary  Gray.800 light / Gray.300 dark
  Color get textSecondary => isDark ? AppColors.gray3 : AppColors.gray8;

  /// text.tertiary  Gray.700 light / Gray.400 dark
  Color get textTertiary => isDark ? AppColors.gray4 : AppColors.gray7;

  /// text.link  Blue.700 light / Blue.200 dark
  Color get textLink => isDark ? AppColors.blue2 : AppColors.blue7;

  /// text.disabled  Gray.600 light / Gray.500 dark
  Color get textDisabled => isDark ? AppColors.gray5 : AppColors.gray6;

  /// text.inverse  Gray.100 light / Gray.900 dark
  Color get textInverse => isDark ? AppColors.gray9 : AppColors.gray1;

  /// text.inverse-color  Blue.400 light / Blue.600 dark
  Color get textInverseColor => isDark ? AppColors.blue6 : AppColors.blue4;

  /// text.promo-icon  Yellow.300 both modes
  Color get textPromoIcon => AppColors.yellow3;

  // ── Background ──────────────────────────────────────────────────────────────

  /// bg.surface  Gray.100 light / Gray.900 dark
  Color get bgSurface => isDark ? AppColors.gray9 : AppColors.gray1;

  /// bg.elevated  White light / Gray.850 dark
  Color get bgElevated => isDark ? AppColors.gray850 : AppColors.white;

  /// bg.input  White light / Gray.850 dark
  Color get bgInput => isDark ? AppColors.gray850 : AppColors.white;

  /// bg.hover  Blue.100 light / Blue.900 dark
  Color get bgHover => isDark ? AppColors.blue9 : AppColors.blue1;

  /// bg.overlay  Gray.100 light / Gray.900 dark
  Color get bgOverlay => isDark ? AppColors.gray9 : AppColors.gray1;

  /// bg.callout  Gray.200 light / Gray.800 dark
  Color get bgCallout => isDark ? AppColors.gray8 : AppColors.gray2;

  /// bg.snackbar  Blue.900 light / Blue.200 dark
  Color get bgSnackbar => isDark ? AppColors.blue2 : AppColors.blue9;

  /// bg.snackbar-error  Red.700 light / Red.500 dark
  Color get bgSnackbarError => isDark ? AppColors.red5 : AppColors.red7;

  /// bg.promo  Yellow.100 light / Gray.900 dark
  Color get bgPromo => isDark ? AppColors.gray9 : AppColors.yellow1;

  // ── Border ──────────────────────────────────────────────────────────────────

  /// border.default  Gray.200 light / Gray.800 dark
  Color get borderDefault => isDark ? AppColors.gray8 : AppColors.gray2;

  /// border.input  Gray.300 light / Gray.700 dark
  Color get borderInput => isDark ? AppColors.gray7 : AppColors.gray3;

  /// border.input-focus  Blue.800 light / Blue.200 dark
  Color get borderInputFocus => isDark ? AppColors.blue2 : AppColors.blue8;

  /// border.input-filled  Gray.900 light / Gray.400 dark
  Color get borderInputFilled => isDark ? AppColors.gray4 : AppColors.gray9;

  /// border.error  Red.600 light / Red.500 dark
  Color get borderError => isDark ? AppColors.red5 : AppColors.red6;

  /// border.promo  Yellow.500 both modes
  Color get borderPromo => AppColors.yellow5;

  // ── Status ──────────────────────────────────────────────────────────────────

  /// status.error-text  Red.800 light / Red.200 dark
  Color get statusErrorText => isDark ? AppColors.red2 : AppColors.red8;

  /// status.error-bg  Red.200 light / Red.800 dark
  Color get statusErrorBg => isDark ? AppColors.red8 : AppColors.red2;

  /// status.error-border  Red.400 light / Red.600 dark
  Color get statusErrorBorder => isDark ? AppColors.red6 : AppColors.red4;

  /// status.success-text  Green.800 light / Green.300 dark
  Color get statusSuccessText => isDark ? AppColors.green3 : AppColors.green8;

  /// status.success-bg  Green.200 light / Green.700 dark
  Color get statusSuccessBg => isDark ? AppColors.green7 : AppColors.green2;

  /// status.success-border  Green.400 light / Green.600 dark
  Color get statusSuccessBorder =>
      isDark ? AppColors.green6 : AppColors.green4;

  /// status.warning-text  Yellow.500 light / Yellow.200 dark
  Color get statusWarningText => isDark ? AppColors.yellow2 : AppColors.yellow5;

  /// status.warning-bg-dot  Yellow.300 light / Yellow.500 dark
  Color get statusWarningBgDot =>
      isDark ? AppColors.yellow5 : AppColors.yellow3;

  /// status.neutral-text  Gray.600 light / Gray.200 dark
  Color get statusNeutralText => isDark ? AppColors.gray2 : AppColors.gray6;

  /// status.informational-text  Blue.800 light / Blue.200 dark
  Color get statusInfoText => isDark ? AppColors.blue2 : AppColors.blue8;

  /// status.Informational-bg  Blue.200 light / Blue.700 dark
  Color get statusInfoBg => isDark ? AppColors.blue7 : AppColors.blue2;

  /// status.Informational-border  Blue.400 light / Blue.600 dark
  Color get statusInfoBorder => isDark ? AppColors.blue6 : AppColors.blue4;

  /// status.error-bg-dot  Red.600 light / Red.800 dark
  Color get statusErrorBgDot => isDark ? AppColors.red8 : AppColors.red6;

  /// status.error-border-dot  Red.300 light / Red.500 dark
  Color get statusErrorBorderDot => isDark ? AppColors.red5 : AppColors.red3;

  /// status.warning-border-dot  Yellow.200 light / Yellow.400 dark
  Color get statusWarningBorderDot =>
      isDark ? AppColors.yellow4 : AppColors.yellow2;

  /// status.success-bg-dot  Green.600 light / Green.700 dark
  Color get statusSuccessBgDot =>
      isDark ? AppColors.green7 : AppColors.green6;

  /// status.success-border-dot  Green.300 light / Green.500 dark
  Color get statusSuccessBorderDot =>
      isDark ? AppColors.green5 : AppColors.green3;

  /// status.neutral-bg-dot  Gray.500 light / Gray.700 dark
  Color get statusNeutralBgDot => isDark ? AppColors.gray7 : AppColors.gray5;

  /// status.neutral-border-dot  Gray.300 light / Gray.500 dark
  Color get statusNeutralBorderDot =>
      isDark ? AppColors.gray5 : AppColors.gray3;

  // ── Action / Primary ────────────────────────────────────────────────────────

  /// action.primary.primary-bg  Blue.1000 light / Blue.600 dark
  Color get actionPrimaryBg => isDark ? AppColors.blue6 : AppColors.blue10;

  /// action.primary.primary-bg-hover  Blue.800 light / Blue.500 dark
  Color get actionPrimaryBgHover => isDark ? AppColors.blue5 : AppColors.blue8;

  /// action.primary.primary-text  Gray.100 both modes
  Color get actionPrimaryText => AppColors.gray1;

  /// action.primary.primary-disabled-bg  Gray.200 light / Gray.700 dark
  Color get actionPrimaryDisabledBg =>
      isDark ? AppColors.gray7 : AppColors.gray2;

  /// action.primary.primary-disabled-text  Gray.500 both modes
  Color get actionPrimaryDisabledText => AppColors.gray5;

  /// action.primary.primary-disabled-border  Gray.400 light / Gray.500 dark
  Color get actionPrimaryDisabledBorder =>
      isDark ? AppColors.gray5 : AppColors.gray4;

  // ── Action / Secondary ──────────────────────────────────────────────────────

  /// action.secondary.secondary-bg  Gray.100 light / Gray.900 dark
  Color get actionSecondaryBg => isDark ? AppColors.gray9 : AppColors.gray1;

  /// action.secondary.secondary-bg-hover  Gray.200 light / Gray.800 dark
  Color get actionSecondaryBgHover =>
      isDark ? AppColors.gray8 : AppColors.gray2;

  /// action.secondary.secondary-text  Gray.900 light / Gray.100 dark
  Color get actionSecondaryText => isDark ? AppColors.gray1 : AppColors.gray9;

  /// action.secondary.secondary-border  Gray.500 light / Gray.600 dark
  Color get actionSecondaryBorder =>
      isDark ? AppColors.gray6 : AppColors.gray5;

  /// action.secondary.secondary-disabled-bg  Gray.200 light / Gray.900 dark
  Color get actionSecondaryDisabledBg =>
      isDark ? AppColors.gray9 : AppColors.gray2;

  /// action.secondary.secondary-disabled-text  Gray.500 both modes
  Color get actionSecondaryDisabledText => AppColors.gray5;

  /// action.secondary.secondary-disabled-border  Gray.300 light / Gray.700 dark
  Color get actionSecondaryDisabledBorder =>
      isDark ? AppColors.gray7 : AppColors.gray3;

  // ── Action / Tertiary ───────────────────────────────────────────────────────

  /// action.tertiary.tertiary-text  Gray.900 light / Gray.100 dark
  Color get actionTertiaryText => isDark ? AppColors.gray1 : AppColors.gray9;

  /// action.tertiary.tertiary-hover-bg  Gray.200 light / Gray.800 dark
  Color get actionTertiaryHoverBg =>
      isDark ? AppColors.gray8 : AppColors.gray2;

  /// action.tertiary.tertiary-disabled-text  Gray.500 both modes
  Color get actionTertiaryDisabledText => AppColors.gray5;

  // ── Action / Tonal ──────────────────────────────────────────────────────────

  /// action.tonal.tonal-bg  Blue.100 light / Blue.700 dark
  Color get actionTonalBg => isDark ? AppColors.blue7 : AppColors.blue1;

  /// action.tonal.tonal-border  Gray.200 light / Gray.800 dark
  Color get actionTonalBorder => isDark ? AppColors.gray8 : AppColors.gray2;

  /// action.tonal.tonal-bg-hover  Blue.200 light / Blue.600 dark
  Color get actionTonalBgHover => isDark ? AppColors.blue6 : AppColors.blue2;

  /// action.tonal.tonal-text  Gray.900 light / Gray.100 dark
  Color get actionTonalText => isDark ? AppColors.gray1 : AppColors.gray9;

  /// action.tonal.tonal-disabled-bg  Gray.100 light / Gray.800 dark
  Color get actionTonalDisabledBg =>
      isDark ? AppColors.gray8 : AppColors.gray1;

  /// action.tonal.tonal-disabled-border  Gray.200 light / Gray.800 dark
  Color get actionTonalDisabledBorder =>
      isDark ? AppColors.gray8 : AppColors.gray2;

  /// action.tonal.tonal-disabled-text  Gray.400 light / Gray.500 dark
  Color get actionTonalDisabledText =>
      isDark ? AppColors.gray5 : AppColors.gray4;

  // ── Action / Toggle ─────────────────────────────────────────────────────────

  /// action.toggle.toggle-active-bg  Green.500 light / Green.700 dark
  Color get actionToggleActiveBg =>
      isDark ? AppColors.green7 : AppColors.green5;

  /// action.toggle.toggle-brand-active-bg  Blue.400 light / Blue.600 dark
  Color get actionToggleBrandActiveBg =>
      isDark ? AppColors.blue6 : AppColors.blue4;

  /// action.toggle.toggle-disabled-bg  Gray.700 both modes
  Color get actionToggleDisabledBg => AppColors.gray7;

  /// action.toggle.toggle-knob-bg  Gray.000 light / Gray.100 dark
  Color get actionToggleKnobBg => isDark ? AppColors.gray1 : AppColors.gray0;

  /// action.toggle.toggle-border  Gray.200 light / Gray.700 dark
  Color get actionToggleBorder => isDark ? AppColors.gray7 : AppColors.gray2;

  // ── Action / Tabbar ─────────────────────────────────────────────────────────

  /// action.tabbar.tabbar-bg  Blue.200 light / Blue.800 dark
  Color get actionTabbarBg => isDark ? AppColors.blue8 : AppColors.blue2;

  /// action.tabbar.tabbar-border  Blue.300 light / Blue.700 dark
  Color get actionTabbarBorder => isDark ? AppColors.blue7 : AppColors.blue3;

  /// action.tabbar.tabbar-selected-text  Blue.1000 light / Blue.100 dark
  Color get actionTabbarSelectedText =>
      isDark ? AppColors.blue1 : AppColors.blue10;

  /// action.tabbar.tabbar-disabled-text  Gray.600 light / Gray.200 dark
  Color get actionTabbarDisabledText =>
      isDark ? AppColors.gray2 : AppColors.gray6;
}
