import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
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

  Widget? _buildPrefix(Object? iconPath) {
    if (iconPath == null) return null;
    const pad = EdgeInsets.only(left: 16, right: 16);
    if (iconPath is IconData) {
      return Padding(
        padding: pad,
        child: Icon(iconPath, color: AppColors.yellow9),
      );
    } else if (iconPath is String) {
      return Padding(
        padding: pad,
        child: AppImage(path: iconPath, color: AppColors.yellow9),
      );
    } else if (iconPath is Widget) {
      return Padding(padding: pad, child: iconPath);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: _buildPrefix(prefixIcon),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: enabled ? AppColors.white : AppColors.gray3.withOpacity(0.3),
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.gray4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.gray3, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.gray3, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.blue4, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.red5, width: 1.2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppColors.gray3.withOpacity(0.5), width: 1),
        ),
      ),
      style: AppTextStyles.bodyMedium.copyWith(
        color: enabled ? AppColors.black1 : AppColors.gray4,
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: null), // uses default IconTheme
      isExpanded: true,
    );
  }
}
