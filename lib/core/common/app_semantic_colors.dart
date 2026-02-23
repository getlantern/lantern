import 'package:flutter/material.dart';
import 'app_colors.dart';

/// BuildContext extension that maps Figma Color/Semantic tokens to AppColors.
/// Every property has a light and dark value derived directly from the JSON export.
///
/// Usage:  context.textPrimary, context.bgElevated, context.borderInput …
extension AppSemanticColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Text ────────────────────────────────────────────────────────────────────

  /// text.primary  Gray.900 light / Gray.200 dark
  Color get textPrimary => _isDark ? AppColors.gray2 : AppColors.gray9;

  /// text.secondary  Gray.800 light / Gray.300 dark
  Color get textSecondary => _isDark ? AppColors.gray3 : AppColors.gray8;

  /// text.tertiary  Gray.700 light / Gray.400 dark
  Color get textTertiary => _isDark ? AppColors.gray4 : AppColors.gray7;

  /// text.link  Blue.700 light / Blue.200 dark
  Color get textLink => _isDark ? AppColors.blue2 : AppColors.blue7;

  /// text.disabled  Gray.600 light / Gray.500 dark
  Color get textDisabled => _isDark ? AppColors.gray5 : AppColors.gray6;

  /// text.inverse  Gray.100 light / Gray.900 dark
  Color get textInverse => _isDark ? AppColors.gray9 : AppColors.gray1;

  /// text.inverse-color  Blue.400 light / Blue.600 dark
  Color get textInverseColor => _isDark ? AppColors.blue6 : AppColors.blue4;

  /// text.promo-icon  Yellow.300 both modes
  Color get textPromoIcon => AppColors.yellow3;

  // ── Background ──────────────────────────────────────────────────────────────

  /// bg.surface  Gray.100 light / Gray.900 dark
  Color get bgSurface => _isDark ? AppColors.gray9 : AppColors.gray1;

  /// bg.elevated  White light / Gray.850 dark
  Color get bgElevated => _isDark ? AppColors.gray850 : AppColors.white;

  /// bg.input  White light / Gray.850 dark
  Color get bgInput => _isDark ? AppColors.gray850 : AppColors.white;

  /// bg.hover  Blue.100 light / Blue.900 dark
  Color get bgHover => _isDark ? AppColors.blue9 : AppColors.blue1;

  /// bg.overlay  Gray.100 light / Gray.900 dark
  Color get bgOverlay => _isDark ? AppColors.gray9 : AppColors.gray1;

  /// bg.callout  Gray.200 light / Gray.800 dark
  Color get bgCallout => _isDark ? AppColors.gray8 : AppColors.gray2;

  /// bg.snackbar  Blue.900 light / Blue.200 dark
  Color get bgSnackbar => _isDark ? AppColors.blue2 : AppColors.blue9;

  /// bg.snackbar-error  Red.700 light / Red.500 dark
  Color get bgSnackbarError => _isDark ? AppColors.red5 : AppColors.red7;

  /// bg.promo  Yellow.100 light / Gray.900 dark
  Color get bgPromo => _isDark ? AppColors.gray9 : AppColors.yellow1;

  // ── Border ──────────────────────────────────────────────────────────────────

  /// border.default  Gray.200 light / Gray.800 dark
  Color get borderDefault => _isDark ? AppColors.gray8 : AppColors.gray2;

  /// border.input  Gray.300 light / Gray.700 dark
  Color get borderInput => _isDark ? AppColors.gray7 : AppColors.gray3;

  /// border.input-focus  Blue.800 light / Blue.200 dark
  Color get borderInputFocus => _isDark ? AppColors.blue2 : AppColors.blue8;

  /// border.input-filled  Gray.900 light / Gray.400 dark
  Color get borderInputFilled => _isDark ? AppColors.gray4 : AppColors.gray9;

  /// border.error  Red.600 light / Red.500 dark
  Color get borderError => _isDark ? AppColors.red5 : AppColors.red6;

  /// border.promo  Yellow.500 both modes
  Color get borderPromo => AppColors.yellow5;

  // ── Status ──────────────────────────────────────────────────────────────────

  /// status.error-text  Red.800 light / Red.200 dark
  Color get statusErrorText => _isDark ? AppColors.red2 : AppColors.red8;

  /// status.error-bg  Red.200 light / Red.800 dark
  Color get statusErrorBg => _isDark ? AppColors.red8 : AppColors.red2;

  /// status.error-border  Red.400 light / Red.600 dark
  Color get statusErrorBorder => _isDark ? AppColors.red6 : AppColors.red4;

  /// status.success-text  Green.800 light / Green.300 dark
  Color get statusSuccessText => _isDark ? AppColors.green3 : AppColors.green8;

  /// status.success-bg  Green.200 light / Green.700 dark
  Color get statusSuccessBg => _isDark ? AppColors.green7 : AppColors.green2;

  /// status.success-border  Green.400 light / Green.600 dark
  Color get statusSuccessBorder =>
      _isDark ? AppColors.green6 : AppColors.green4;

  /// status.warning-text  Yellow.500 light / Yellow.200 dark
  Color get statusWarningText => _isDark ? AppColors.yellow2 : AppColors.yellow5;

  /// status.warning-bg-dot  Yellow.300 light / Yellow.500 dark
  Color get statusWarningBgDot =>
      _isDark ? AppColors.yellow5 : AppColors.yellow3;

  /// status.neutral-text  Gray.600 light / Gray.200 dark
  Color get statusNeutralText => _isDark ? AppColors.gray2 : AppColors.gray6;

  /// status.informational-text  Blue.800 light / Blue.200 dark
  Color get statusInfoText => _isDark ? AppColors.blue2 : AppColors.blue8;

  /// status.Informational-bg  Blue.200 light / Blue.700 dark
  Color get statusInfoBg => _isDark ? AppColors.blue7 : AppColors.blue2;

  /// status.Informational-border  Blue.400 light / Blue.600 dark
  Color get statusInfoBorder => _isDark ? AppColors.blue6 : AppColors.blue4;

  /// status.error-bg-dot  Red.600 light / Red.800 dark
  Color get statusErrorBgDot => _isDark ? AppColors.red8 : AppColors.red6;

  /// status.error-border-dot  Red.300 light / Red.500 dark
  Color get statusErrorBorderDot => _isDark ? AppColors.red5 : AppColors.red3;

  /// status.warning-border-dot  Yellow.200 light / Yellow.400 dark
  Color get statusWarningBorderDot =>
      _isDark ? AppColors.yellow4 : AppColors.yellow2;

  /// status.success-bg-dot  Green.600 light / Green.700 dark
  Color get statusSuccessBgDot =>
      _isDark ? AppColors.green7 : AppColors.green6;

  /// status.success-border-dot  Green.300 light / Green.500 dark
  Color get statusSuccessBorderDot =>
      _isDark ? AppColors.green5 : AppColors.green3;

  /// status.neutral-bg-dot  Gray.500 light / Gray.700 dark
  Color get statusNeutralBgDot => _isDark ? AppColors.gray7 : AppColors.gray5;

  /// status.neutral-border-dot  Gray.300 light / Gray.500 dark
  Color get statusNeutralBorderDot =>
      _isDark ? AppColors.gray5 : AppColors.gray3;

  // ── Action / Primary ────────────────────────────────────────────────────────

  /// action.primary.primary-bg  Blue.1000 light / Blue.600 dark
  Color get actionPrimaryBg => _isDark ? AppColors.blue6 : AppColors.blue10;

  /// action.primary.primary-bg-hover  Blue.800 light / Blue.500 dark
  Color get actionPrimaryBgHover => _isDark ? AppColors.blue5 : AppColors.blue8;

  /// action.primary.primary-text  Gray.100 both modes
  Color get actionPrimaryText => AppColors.gray1;

  /// action.primary.primary-disabled-bg  Gray.200 light / Gray.700 dark
  Color get actionPrimaryDisabledBg =>
      _isDark ? AppColors.gray7 : AppColors.gray2;

  /// action.primary.primary-disabled-text  Gray.500 both modes
  Color get actionPrimaryDisabledText => AppColors.gray5;

  /// action.primary.primary-disabled-border  Gray.400 light / Gray.500 dark
  Color get actionPrimaryDisabledBorder =>
      _isDark ? AppColors.gray5 : AppColors.gray4;

  // ── Action / Secondary ──────────────────────────────────────────────────────

  /// action.secondary.secondary-bg  Gray.100 light / Gray.900 dark
  Color get actionSecondaryBg => _isDark ? AppColors.gray9 : AppColors.gray1;

  /// action.secondary.secondary-bg-hover  Gray.200 light / Gray.800 dark
  Color get actionSecondaryBgHover =>
      _isDark ? AppColors.gray8 : AppColors.gray2;

  /// action.secondary.secondary-text  Gray.900 light / Gray.100 dark
  Color get actionSecondaryText => _isDark ? AppColors.gray1 : AppColors.gray9;

  /// action.secondary.secondary-border  Gray.500 light / Gray.600 dark
  Color get actionSecondaryBorder =>
      _isDark ? AppColors.gray6 : AppColors.gray5;

  /// action.secondary.secondary-disabled-bg  Gray.200 light / Gray.900 dark
  Color get actionSecondaryDisabledBg =>
      _isDark ? AppColors.gray9 : AppColors.gray2;

  /// action.secondary.secondary-disabled-text  Gray.500 both modes
  Color get actionSecondaryDisabledText => AppColors.gray5;

  /// action.secondary.secondary-disabled-border  Gray.300 light / Gray.700 dark
  Color get actionSecondaryDisabledBorder =>
      _isDark ? AppColors.gray7 : AppColors.gray3;

  // ── Action / Tertiary ───────────────────────────────────────────────────────

  /// action.tertiary.tertiary-text  Gray.900 light / Gray.100 dark
  Color get actionTertiaryText => _isDark ? AppColors.gray1 : AppColors.gray9;

  /// action.tertiary.tertiary-hover-bg  Gray.200 light / Gray.800 dark
  Color get actionTertiaryHoverBg =>
      _isDark ? AppColors.gray8 : AppColors.gray2;

  /// action.tertiary.tertiary-disabled-text  Gray.500 both modes
  Color get actionTertiaryDisabledText => AppColors.gray5;

  // ── Action / Tonal ──────────────────────────────────────────────────────────

  /// action.tonal.tonal-bg  Blue.100 light / Blue.700 dark
  Color get actionTonalBg => _isDark ? AppColors.blue7 : AppColors.blue1;

  /// action.tonal.tonal-border  Gray.200 light / Gray.800 dark
  Color get actionTonalBorder => _isDark ? AppColors.gray8 : AppColors.gray2;

  /// action.tonal.tonal-bg-hover  Blue.200 light / Blue.600 dark
  Color get actionTonalBgHover => _isDark ? AppColors.blue6 : AppColors.blue2;

  /// action.tonal.tonal-text  Gray.900 light / Gray.100 dark
  Color get actionTonalText => _isDark ? AppColors.gray1 : AppColors.gray9;

  /// action.tonal.tonal-disabled-bg  Gray.100 light / Gray.800 dark
  Color get actionTonalDisabledBg =>
      _isDark ? AppColors.gray8 : AppColors.gray1;

  /// action.tonal.tonal-disabled-border  Gray.200 light / Gray.800 dark
  Color get actionTonalDisabledBorder =>
      _isDark ? AppColors.gray8 : AppColors.gray2;

  /// action.tonal.tonal-disabled-text  Gray.400 light / Gray.500 dark
  Color get actionTonalDisabledText =>
      _isDark ? AppColors.gray5 : AppColors.gray4;

  // ── Action / Toggle ─────────────────────────────────────────────────────────

  /// action.toggle.toggle-active-bg  Green.500 light / Green.700 dark
  Color get actionToggleActiveBg =>
      _isDark ? AppColors.green7 : AppColors.green5;

  /// action.toggle.toggle-brand-active-bg  Blue.400 light / Blue.600 dark
  Color get actionToggleBrandActiveBg =>
      _isDark ? AppColors.blue6 : AppColors.blue4;

  /// action.toggle.toggle-disabled-bg  Gray.700 both modes
  Color get actionToggleDisabledBg => AppColors.gray7;

  /// action.toggle.toggle-knob-bg  Gray.000 light / Gray.100 dark
  Color get actionToggleKnobBg => _isDark ? AppColors.gray1 : AppColors.gray0;

  /// action.toggle.toggle-border  Gray.200 light / Gray.700 dark
  Color get actionToggleBorder => _isDark ? AppColors.gray7 : AppColors.gray2;

  // ── Action / Tabbar ─────────────────────────────────────────────────────────

  /// action.tabbar.tabbar-bg  Blue.200 light / Blue.800 dark
  Color get actionTabbarBg => _isDark ? AppColors.blue8 : AppColors.blue2;

  /// action.tabbar.tabbar-border  Blue.300 light / Blue.700 dark
  Color get actionTabbarBorder => _isDark ? AppColors.blue7 : AppColors.blue3;

  /// action.tabbar.tabbar-selected-text  Blue.1000 light / Blue.100 dark
  Color get actionTabbarSelectedText =>
      _isDark ? AppColors.blue1 : AppColors.blue10;

  /// action.tabbar.tabbar-disabled-text  Gray.600 light / Gray.200 dark
  Color get actionTabbarDisabledText =>
      _isDark ? AppColors.gray2 : AppColors.gray6;
}
