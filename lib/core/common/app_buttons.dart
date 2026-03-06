import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/cap_scaling.dart';

typedef OnPressed = VoidCallback;

class PrimaryButton extends StatelessWidget {
  final String label;

  final bool enabled;
  final bool showBorder;

  final bool expanded;
  final VoidCallback onPressed;
  final String? icon;
  final Color? iconColor;

  final Color? bgColor;
  final Color? textColor;
  final bool? isTaller;
  final bool? useThemeColor;

  // Default constructor for button without an icon
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.bgColor,
    this.iconColor,
    this.textColor,
    this.enabled = true,
    this.expanded = true,
    this.isTaller = false,
    this.showBorder = false,
    this.useThemeColor,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final button = Theme.of(context).elevatedButtonTheme.style;

    final iconHeight = hCap(context, 22);
    final iconSz = spCap(context, 24);

    return icon == null
        ? ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: _buildButtonStyle(context, button!, iconSz),
            child: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: AppImage(
              path: icon!,
              height: iconHeight,
              color: iconColor,
              useThemeColor: useThemeColor ?? true,
            ),
            label: Text(label),
            style: _buildButtonStyle(context, button!, iconSz),
          );
  }

  ButtonStyle _buildButtonStyle(
    BuildContext context,
    ButtonStyle style,
    double iconSz,
  ) {
    final verticalPad = hCap(context, 12);
    final fontSz = spCap(context, 16);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Heights
    final minHeight = isTaller == true ? hCap(context, 56) : hCap(context, 48);
    final nonExpandedHeight = hCap(context, 52);

    return style.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            // primary-disabled-bg: Gray.200 light / Gray.700 dark
            return isDark ? AppColors.gray7 : AppColors.gray2;
          }
          if (states.contains(WidgetState.hovered) &&
              bgColor == AppColors.blue1) {
            return AppColors.blue2;
          }
          if (states.contains(WidgetState.hovered)) {
            // primary-bg-hover: Blue.800 light / Blue.500 dark
            return isDark ? AppColors.blue5 : AppColors.blue8;
          }
          // primary-bg: Blue.1000 light / Blue.600 dark
          return bgColor ?? (isDark ? AppColors.blue6 : AppColors.blue10);
        },
      ),
      side: WidgetStateProperty.resolveWith<BorderSide>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            // primary-disabled-border: Gray.400 light / Gray.500 dark
            return BorderSide(
              color: isDark ? AppColors.gray5 : AppColors.gray4,
              width: 1,
            );
          }
          if (showBorder) {
            return BorderSide(
              color: isDark ? AppColors.gray7 : AppColors.gray2,
              width: 1,
            );
          }
          return BorderSide.none;
        },
      ),
      iconSize: WidgetStatePropertyAll<double>(iconSz),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(vertical: verticalPad, horizontal: 40.0),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        AppTextStyles.primaryButtonTextStyle.copyWith(
          fontSize: expanded ? fontSz : 16.0,
          fontWeight: FontWeight.w500,
        ),
      ),
      // primary-text: Gray.100 both / primary-disabled-text: Gray.500 both
      foregroundColor: WidgetStatePropertyAll<Color>(
        enabled == false ? AppColors.gray5 : textColor ?? AppColors.gray1,
      ),
      minimumSize: WidgetStatePropertyAll<Size>(
        expanded
            ? Size(double.infinity, minHeight)
            : Size(0, nonExpandedHeight),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;

  final bool enabled;

  final bool expanded;
  final VoidCallback onPressed;
  final String? icon;

  final Color? bgColor;
  final bool? isTaller;
  final bool? useThemeColor;
  final Color? foregroundColor;
  final bool? removeBorder;

  const SecondaryButton({
    super.key,
    required this.label,
    this.enabled = true,
    this.expanded = true,
    this.isTaller = false,
    required this.onPressed,
    this.icon,
    this.bgColor,
    this.useThemeColor,
    this.foregroundColor,
    this.removeBorder,
  });

  @override
  Widget build(BuildContext context) {
    final button = Theme.of(context).elevatedButtonTheme.style;

    final iconHeight = hCap(context, 22);
    final iconSz = spCap(context, 24);

    return icon == null
        ? ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: _buildButtonStyle(context, button!, iconSz),
            child: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: AppImage(
              path: icon!,
              height: iconHeight,
              color: foregroundColor,
              useThemeColor: useThemeColor ?? false,
            ),
            label: Text(label),
            style: _buildButtonStyle(context, button!, iconSz),
          );
  }

  ButtonStyle _buildButtonStyle(
    BuildContext context,
    ButtonStyle style,
    double iconSz,
  ) {
    final verticalPad = hCap(context, 12);
    final fontSz = spCap(context, 16);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Heights
    final height = isTaller == true ? hCap(context, 56) : hCap(context, 50);

    return style.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            // secondary-disabled-bg: Gray.200 light / Gray.900 dark
            return isDark ? AppColors.gray9 : AppColors.gray2;
          }
          if (states.contains(WidgetState.hovered)) {
            // secondary-bg-hover: Gray.200 light / Gray.800 dark
            return context.actionSecondaryBgHover;
          }
          // secondary-bg: Gray.100 light / Gray.900 dark
          return bgColor ?? context.actionSecondaryBg;
        },
      ),
      side: WidgetStateProperty.resolveWith<BorderSide>(
        (Set<WidgetState> states) {
          if (removeBorder ?? false) {
            return BorderSide.none;
          }

          if (states.contains(WidgetState.disabled)) {
            // secondary-disabled-border: Gray.400 light / Gray.700 dark
            return BorderSide(
              color: isDark ? AppColors.gray7 : AppColors.gray4,
              width: 1,
            );
          }
          // secondary-border: Gray.500 light / Gray.600 dark
          return BorderSide(
            color: isDark ? AppColors.gray6 : AppColors.gray5,
            width: 1,
          );
        },
      ),
      // secondary-bg-hover used as overlay
      overlayColor: WidgetStatePropertyAll<Color>(
        isDark ? AppColors.gray8 : AppColors.gray2,
      ),
      foregroundColor:
          WidgetStatePropertyAll<Color>(foregroundColor ?? context.textPrimary),
      iconSize: WidgetStatePropertyAll<double>(iconSz),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(vertical: verticalPad, horizontal: 40.0),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        AppTextStyles.primaryButtonTextStyle.copyWith(
          fontSize: expanded ? fontSz : 16.0,
          fontWeight: FontWeight.w600,
        ),
      ),
      maximumSize: WidgetStatePropertyAll<Size>(Size(double.infinity, height)),
      minimumSize: WidgetStatePropertyAll<Size>(Size(double.infinity, height)),
    );
  }
}

class AppTextButton extends StatelessWidget {
  final String label;

  final OnPressed? onPressed;

  final Color? textColor;
  final EdgeInsets? padding;
  final double? fontSize;
  final bool underLine;

  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.textColor,
    this.padding,
    this.underLine = true,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final cappedFontSize = fontSize == null ? null : spCap(context, fontSize!);

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: padding ?? EdgeInsets.symmetric(horizontal: defaultSize),
        visualDensity: VisualDensity.compact,
        textStyle: AppTextStyles.titleMedium.copyWith(
          overflow: TextOverflow.ellipsis,
          decoration:
              underLine ? TextDecoration.underline : TextDecoration.none,
          fontSize: cappedFontSize,
        ),
        // text.link from semantic token
        foregroundColor: textColor ?? context.textLink,
      ),
      child: Text(label),
    );
  }
}

class AppIconButton extends StatelessWidget {
  final String path;
  final OnPressed? onPressed;

  const AppIconButton({
    super.key,
    required this.path,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final iconHeight = hCap(context, 24);

    return IconButton(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      icon: AppImage(
        path: path,
        height: iconHeight,
      ),
    );
  }
}

class AppRadioButton<T> extends StatelessWidget {
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  const AppRadioButton({
    super.key,
    required this.value,
    this.groupValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sz = hCap(context, 24);
    return SizedBox(
      width: sz,
      height: sz,
      child: Radio<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: context.textLink,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
