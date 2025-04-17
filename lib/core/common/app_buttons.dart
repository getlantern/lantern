import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';

typedef OnPressed = VoidCallback;

class PrimaryButton extends StatelessWidget {
  final String label;

  final bool enabled;

  final bool expanded;
  final VoidCallback onPressed;
  final String? icon;

  final Color? bgColor;

  // Default constructor for button without an icon
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.bgColor,
    this.enabled = true,
    this.expanded = true,
    this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final button = Theme.of(context).elevatedButtonTheme.style;
    return icon == null
        ? ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: _buildButtonStyle(button!),
            child: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: AppImage(
              path: icon!,
              height: 22,
            ),
            label: Text(label),
            style: _buildButtonStyle(button!),
          );
  }

  ButtonStyle _buildButtonStyle(ButtonStyle style) {
    return style.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.gray2; // Disabled background color
          }
          return bgColor ?? AppColors.blue10; // Default background color
        },
      ),
      side: WidgetStateProperty.resolveWith<BorderSide>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: AppColors.gray4, width: 1);
          }
          return BorderSide.none;
        },
      ),
      // backgroundColor: WidgetStatePropertyAll<Color>(bgColor ?? AppColors.blue7),
      iconSize: WidgetStatePropertyAll<double>(24.0),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(vertical: 12.0.h, horizontal: 40.0)),
      textStyle: WidgetStatePropertyAll<TextStyle>(
          AppTestStyles.primaryButtonTextStyle.copyWith(
              fontSize: expanded ? 16.0.sp : 16.0,
              color: AppColors.gray1,
              fontWeight: FontWeight.w600)),
      minimumSize: WidgetStatePropertyAll<Size>(
          expanded ? const Size(double.infinity, 52.0) : const Size(0, 52.0)),
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

  const SecondaryButton(
      {super.key,
      required this.label,
      this.enabled = true,
      this.expanded = true,
      required this.onPressed,
      this.icon,
      this.bgColor});

  @override
  Widget build(BuildContext context) {
    final button = Theme.of(context).elevatedButtonTheme.style;
    return icon == null
        ? ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: _buildButtonStyle(button!),
            child: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: AppImage(
              path: icon!,
              height: 22,
            ),
            label: Text(label),
            style: _buildButtonStyle(button!),
          );
  }

  ButtonStyle _buildButtonStyle(ButtonStyle style) {
    return style.copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.gray2; // Disabled background color
          }
          return bgColor ?? AppColors.gray1; // Default background color
        },
      ),
      side: WidgetStateProperty.resolveWith<BorderSide>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: AppColors.gray4, width: 1);
          }
          return BorderSide(color: AppColors.gray4, width: 1);
        },
      ),
      overlayColor: WidgetStatePropertyAll<Color>(AppColors.gray2),
      foregroundColor: WidgetStatePropertyAll<Color>(AppColors.gray9),
      iconSize: WidgetStatePropertyAll<double>(24.0),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(vertical: 12.0.h, horizontal: 40.0)),
      textStyle: WidgetStatePropertyAll<TextStyle>(
          AppTestStyles.primaryButtonTextStyle.copyWith(
              fontSize: expanded ? 16.0.sp : 16.0,
              color: AppColors.gray9,
              fontWeight: FontWeight.w600)),
      minimumSize:
          WidgetStatePropertyAll<Size>(const Size(double.infinity, 52.0)),
    );
  }
}

class AppTextButton extends StatelessWidget {
  final String label;

  final OnPressed onPressed;

  final Color? textColor;
  final EdgeInsets? padding;

  const AppTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.textColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: padding ?? EdgeInsets.symmetric(horizontal: 16.0),
        visualDensity: VisualDensity.compact,
        textStyle: AppTestStyles.titleMedium.copyWith(
          overflow: TextOverflow.ellipsis,
          decoration: TextDecoration.underline,
        ),
        foregroundColor: textColor ?? AppColors.blue7,
      ),
      child: Text(label),
    );
  }
}

class AppIconButton extends StatelessWidget {
  final String path;
  final OnPressed onPressed;

  const AppIconButton({
    super.key,
    required this.path,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      icon: AppImage(
        path: path,
        height: 24,
      ),
    );
  }
}
