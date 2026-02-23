import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class CardDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;
  final String? hintText;
  final Object? prefixIcon;
  final bool enabled;

  const CardDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.hintText,
    this.prefixIcon,
    this.enabled = true,
  });

  Widget? _buildPrefix(Object? iconPath, BuildContext context) {
    if (iconPath == null) return null;
    const pad = EdgeInsets.only(left: 16, right: 16);
    if (iconPath is IconData) {
      return Padding(
        padding: pad,
        child: Icon(iconPath, color: context.textPromoIcon),
      );
    } else if (iconPath is String) {
      return Padding(
        padding: pad,
        child: AppImage(path: iconPath, color: context.textPromoIcon),
      );
    } else if (iconPath is Widget) {
      return Padding(padding: pad, child: iconPath);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: _buildPrefix(prefixIcon, context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: enabled ? context.bgElevated : context.borderInput.withOpacity(0.3),
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: context.textDisabled),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.borderInput, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.borderInput, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.blue4, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.statusErrorBorder, width: 1.2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: context.borderInput.withOpacity(0.5), width: 1),
        ),
      ),
      style: AppTextStyles.bodyMedium.copyWith(
        color: enabled ? context.textPrimary : context.textDisabled,
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: null), // uses default IconTheme
      isExpanded: true,
    );
  }
}
