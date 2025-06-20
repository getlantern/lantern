import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class CardDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;
  final String? hintText;
  final String? prefixIcon;
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

  Widget _buildFix(Object iconPath) {
    Widget? appAsset;
    if (iconPath is IconData) {
      appAsset = Icon(iconPath, color: AppColors.yellow9);
    } else if (iconPath is String) {
      appAsset = AppImage(
        path: iconPath,
        color: AppColors.yellow9,
      );
    } else if (iconPath is Widget) {
      appAsset = iconPath;
    }
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 14.h, bottom: 14.h),
      child: Align(
        alignment: Alignment.topCenter,
        widthFactor: 1.0,
        heightFactor: 1.toDouble(),
        child: appAsset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: _buildFix(prefixIcon!),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: enabled ? Colors.white : AppColors.gray3.withOpacity(0.3),
        hintText: hintText,
        hintStyle: AppTestStyles.bodyMedium.copyWith(color: AppColors.gray4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFDEDFDF),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFDEDFDF),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF4FB5FF),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1.2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: AppColors.gray3.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      style: AppTestStyles.bodyMedium.copyWith(
        color: enabled ? AppColors.black1 : AppColors.gray4,
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      isExpanded: true,
    );
  }
}
