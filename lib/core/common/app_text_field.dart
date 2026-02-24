import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/common/cap_scaling.dart';

class AppTextField extends StatelessWidget {
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
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
  final bool enableSuggestions;
  final bool obscureText;
  final List<TextInputFormatter> inputFormatters;
  final VoidCallback? onTap;
  final int? maxLength;
  final bool? autocorrect;
  final Widget? counter;
  final List<String>? autofillHints;
  final bool? autofocus;

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
    this.autocorrect,
    this.onSubmitted,
    this.onEditingComplete,
    this.counter,
    this.autofillHints,
    this.autofocus,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget inputField = TextFormField(
        autofocus: autofocus ?? false,
        textAlign: TextAlign.start,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: keyboardType,
        autocorrect: autocorrect ?? !obscureText,
        autofillHints: autofillHints,
        enableSuggestions: enableSuggestions,
        controller: controller,
        maxLength: maxLength,
        enabled: enable,
        initialValue: initialValue,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        onEditingComplete: onEditingComplete,
        readOnly: onTap != null,
        onTap: onTap,
        // cursorColor from textSelectionTheme
        autovalidateMode: autovalidateMode,
        validator: validator,
        cursorRadius: Radius.circular(16),
        cursorHeight: defaultSize,
        cursorOpacityAnimates: true,
        style: textTheme.bodyMedium!.copyWith(
          // text color from colorScheme.onSurface via theme
          fontSize: spCap(context, 14),
        ),
        textInputAction: textInputAction,
        maxLines: maxLines,
        buildCounter: (context,
                {required currentLength,
                required isFocused,
                required maxLength}) =>
            counter,
        decoration: InputDecoration(
          // borders, hintStyle, contentPadding come from inputDecorationTheme
          filled: true,
          fillColor: enable
              ? context.bgElevated   // bg.input = bg.elevated
              : context.bgCallout,   // bg.callout for disabled
          hintText: hintText,
          prefixIcon: prefixIcon != null
              ? _buildFix(prefixIcon!, iconColor: context.textPrimary)
              : null,
          suffixIcon: suffixIcon != null
              ? _buildFix(suffixIcon!, iconColor: context.textPrimary)
              : null,
        ));

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
                color: context.textSecondary, // text.secondary
                fontSize: spCap(context, 14),
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

  Widget _buildFix(Object iconPath, {Color? iconColor}) {
    Widget? appAsset;
    if (iconPath is IconData) {
      appAsset = Icon(iconPath, color: iconColor);
    } else if (iconPath is String) {
      appAsset = AppImage(
        path: iconPath,
        color: iconColor,
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
