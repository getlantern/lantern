import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_dimens.dart';

class AppTextFiled extends StatelessWidget {
  final FormFieldValidator<String>? validator;
  final TextEditingController? controller;

  final bool enable;
  final String hintText;
  final String? initialValue;
  final String? prefixIcon;
  final String? suffixIcon;
  final int maxLines;

  final AutovalidateMode autovalidateMode;

  final TextInputType? keyboardType;
  final bool? enableSuggestions;
  final bool obscureText;

  final List<TextInputFormatter> inputFormatters;

  const AppTextFiled({
    super.key,
    required this.hintText,
    this.validator,
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
    this.initialValue,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme!;
    return TextFormField(
      textAlign: TextAlign.start,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: keyboardType,
      enableSuggestions: true,
      controller: controller,
      enabled: enable,
      initialValue: initialValue,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      cursorColor: AppColors.blue8,
      autovalidateMode: autovalidateMode,
      validator: validator,
      cursorRadius: Radius.circular(16),
      cursorHeight: defaultSize,
      style: textTheme.bodyMedium!.copyWith(
        color: AppColors.gray9,
        fontSize: 14.sp,
      ),
      cursorOpacityAnimates: true,
      maxLines: maxLines,
      decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintText: hintText,
          hintStyle: textTheme.bodyMedium!.copyWith(
            color: AppColors.gray4,
          ),
          prefixIcon: prefixIcon != null ? _buildFix(prefixIcon!) : null,
          suffixIcon: suffixIcon != null ? _buildFix(suffixIcon!) : null,

          border: OutlineInputBorder(
            borderRadius: defaultBorderRadius,
            borderSide: BorderSide(
              color: Colors.grey,
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
  }

  Widget _buildFix(String iconPath) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
      child: Align(
        alignment: Alignment.topCenter,
        widthFactor: 1.0,
        heightFactor: maxLines.toDouble(),
        child: AppAsset(
          path: iconPath,
          color: AppColors.yellow9,
        ),
      ),
    );
  }
}
