import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class CardDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;
  final String? hintText;
  final Object? prefixIcon;
  final bool enabled;
  final Key? formFieldKey;

  const CardDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.hintText,
    this.prefixIcon,
    this.enabled = true,
    this.formFieldKey,
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
    final borderRadius = BorderRadius.circular(16);
    final enabledBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: context.borderInput, width: 1),
    );

    return DropdownButtonFormField<T>(
      key: formFieldKey,
      initialValue: value,
      items: items,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: _buildPrefix(prefixIcon, context),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        filled: true,
        fillColor: enabled
            ? context.bgElevated
            : context.borderInput.withValues(alpha: 0.3),
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: context.textDisabled,
        ),
        border: enabledBorder,
        enabledBorder: enabledBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: context.borderInputFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: context.statusErrorBorder, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: context.statusErrorBorder, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: context.borderInput.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      style: AppTextStyles.bodyMedium.copyWith(
        color: enabled ? context.textPrimary : context.textDisabled,
      ),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: null,
      ), // uses default IconTheme
      isExpanded: true,
      borderRadius: borderRadius,
      dropdownColor: context.bgElevated,
      menuMaxHeight: 320,
    );
  }
}
