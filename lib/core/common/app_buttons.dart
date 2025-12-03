import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';

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
              color: iconColor,
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
          if (states.contains(WidgetState.hovered) &&
              bgColor == AppColors.blue1) {
            return AppColors.blue2; // Pressed background color
          }
          if (states.contains(WidgetState.hovered)) {
            return AppColors.blue8; // Hovered background color
          }
          return bgColor ?? AppColors.blue10; // Default background color
        },
      ),
      side: WidgetStateProperty.resolveWith<BorderSide>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: AppColors.gray4, width: 1);
          }
          if (showBorder) {
            return BorderSide(color: AppColors.gray2, width: 1);
          }
          return BorderSide.none;
        },
      ),
      // backgroundColor: WidgetStatePropertyAll<Color>(bgColor ?? AppColors.blue7),
      iconSize: WidgetStatePropertyAll<double>(24.0),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(vertical: 12.0.h, horizontal: 40.0)),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        AppTextStyles.primaryButtonTextStyle.copyWith(
            fontSize: expanded ? 16.0.sp : 16.0, fontWeight: FontWeight.w500),
      ),

      foregroundColor: WidgetStatePropertyAll<Color>(
        enabled == false ? AppColors.gray5 : textColor ?? AppColors.gray1,
      ),
      minimumSize: WidgetStatePropertyAll<Size>(expanded
          ? Size(double.infinity, isTaller == true ? 56.0 : 48.0)
          : const Size(0, 52.0)),
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

  const SecondaryButton(
      {super.key,
      required this.label,
      this.enabled = true,
      this.expanded = true,
      this.isTaller = false,
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
          AppTextStyles.primaryButtonTextStyle.copyWith(
              fontSize: expanded ? 16.0.sp : 16.0,
              color: AppColors.gray9,
              fontWeight: FontWeight.w600)),
      maximumSize: WidgetStatePropertyAll<Size>(
          Size(double.infinity, isTaller == true ? 56.0 : 50.0)),
      minimumSize: WidgetStatePropertyAll<Size>(
          Size(double.infinity, isTaller == true ? 56.0 : 50.0)),
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
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: padding ?? EdgeInsets.symmetric(horizontal: 16.0),
        visualDensity: VisualDensity.compact,
        textStyle: AppTextStyles.titleMedium.copyWith(
            overflow: TextOverflow.ellipsis,
            decoration:
                underLine ? TextDecoration.underline : TextDecoration.none,
            fontSize: fontSize),
        foregroundColor: textColor ?? AppColors.blue7,
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
    return Radio(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
    );
  }
}
