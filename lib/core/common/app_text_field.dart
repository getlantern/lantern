import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_dimens.dart';

class AppTextField extends StatelessWidget {
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final bool enable;
  final String hintText;
  final String? label;
  final String? initialValue;
  final Object? prefixIcon;
  final Object? suffixIcon;
  final int maxLines;
  final AutovalidateMode autovalidateMode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool? enableSuggestions;
  final bool obscureText;
  final List<TextInputFormatter> inputFormatters;
  final VoidCallback? onTap;
  final int? maxLength;

  const AppTextField({
    super.key,
    required this.hintText,
    this.validator,
    this.onChanged,
    this.label,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.controller,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.enable = true,
    this.enableSuggestions = true,
    this.obscureText = false,
    this.inputFormatters = const [],
    this.keyboardType,
    this.textInputAction,
    this.initialValue,
    this.onTap,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget inputField = TextFormField(
      textAlign: TextAlign.start,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: keyboardType,
      enableSuggestions: true,
      controller: controller,
      maxLength: maxLength,
      enabled: enable,
      initialValue: initialValue,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      onChanged: onChanged,
      readOnly: onTap != null,
      onTap: onTap,
      cursorColor: AppColors.blue10,
      autovalidateMode: autovalidateMode,
      validator: validator,
      cursorRadius: Radius.circular(16),
      cursorHeight: defaultSize,
      cursorOpacityAnimates: true,
      style: textTheme.bodyMedium!.copyWith(
        color: AppColors.gray9,
        fontSize: 14.sp,
      ),
      textInputAction: textInputAction,
      maxLines: maxLines,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          filled: true,
          fillColor: AppColors.white,
          hintText: hintText,
          hintStyle: textTheme.bodyMedium!.copyWith(
            color: AppColors.gray4,
          ),
          prefixIcon: prefixIcon != null ? _buildFix(prefixIcon!) : null,
          suffixIcon: suffixIcon != null ? _buildFix(suffixIcon!) : null,
          border: OutlineInputBorder(
            borderRadius: defaultBorderRadius,
            borderSide: BorderSide(
              color: AppColors.gray3,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: defaultBorderRadius,
            borderSide: BorderSide(
              color: AppColors.gray3,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: defaultBorderRadius,
            borderSide: BorderSide(
              color: AppColors.blue8,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: defaultBorderRadius,
            borderSide: BorderSide(
              color: Colors.grey,
              width: 1,
            ),
          )),
    );

    // If a label is provided, wrap the input field in a Column with a Text widget above.
    if (label != null) {
      final double labelLeftPadding = prefixIcon != null ? 16.0 : 8.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: labelLeftPadding),
            child: Text(
              label!,
              style: textTheme.labelLarge?.copyWith(
                color: AppColors.gray8,
                fontSize: 14.sp,
              ),
            ),
          ),
          const SizedBox(height: 4.0),
          inputField,
        ],
      );
    }

    return inputField;
  }

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
      padding: EdgeInsets.only(left: 16, right: 16, top: 16.h, bottom: 16.h),
      child: Align(
        alignment: Alignment.topCenter,
        widthFactor: 1.0,
        heightFactor: maxLines.toDouble(),
        child: appAsset,
      ),
    );
  }
}
