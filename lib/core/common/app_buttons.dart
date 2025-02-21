import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class PrimaryButton extends StatelessWidget {
  final String label;

  final bool enabled;

  final bool expanded;
  final VoidCallback onPressed;
  final String? icon;

  // Default constructor for button without an icon
  const PrimaryButton({
    required this.label,
    required this.onPressed,
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
            icon: AppAsset(
              path: icon!,
              height: 22,
            ),
            label: Text(label),
            style: _buildButtonStyle(button!),
          );
  }

  ButtonStyle _buildButtonStyle(ButtonStyle style) {
    return style.copyWith(
      iconSize: WidgetStatePropertyAll<double>(24.0),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(vertical: 12.0.h, horizontal: 40.0)),
      textStyle: WidgetStatePropertyAll<TextStyle>(
          AppTestStyles.bodySmall.copyWith(
              fontSize: expanded ? 16.0.sp : 16.0,
              color: AppColors.gray1,
              fontWeight: FontWeight.w600)),
      minimumSize: WidgetStatePropertyAll<Size>(
          expanded ? const Size(double.infinity, 52.0) : const Size(0, 52.0)),
    );
  }
}
