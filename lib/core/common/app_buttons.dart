import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
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
            icon: AppAsset(path: icon!),
            label: Text(label),
            style: _buildButtonStyle(button!),
          );
  }

  ButtonStyle _buildButtonStyle(ButtonStyle style) {
    return style.copyWith(
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(vertical: 12.0, horizontal: 40.0)),
      textStyle: WidgetStatePropertyAll<TextStyle>(AppTestStyles
          .primaryButtonTextStyle
          .copyWith(fontSize: expanded ? 18.0 : 16.0)),
      minimumSize: WidgetStatePropertyAll<Size>(
          expanded ? const Size(double.infinity, 52.0) : const Size(0, 52.0)),
    );
  }
}
