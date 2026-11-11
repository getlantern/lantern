import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/common/cap_scaling.dart';

class AppTextField extends StatelessWidget {
  final Key? fieldKey;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final TextEditingController? controller;
  final FocusNode? focusNode;
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
  final bool enableIMEPersonalizedLearning;
  final bool obscureText;
  final bool enableInteractiveSelection;
  final List<TextInputFormatter> inputFormatters;
  final VoidCallback? onTap;
  final int? maxLength;
  final bool? autocorrect;
  final Widget? counter;
  final List<String>? autofillHints;
  final bool? autofocus;
  final bool expands;
  final double? labelLeftPadding;

  /// The read-only variant: a grey fill, no outline, and no editing. A tap
  /// still reaches [onTap].
  final bool readOnly;

  /// The line under the box: [helperText], or [helper] for one with a link
  /// in it. [errorText] takes the line in the error color while set.
  final String? helperText;
  final Widget? helper;
  final String? errorText;

  /// For tests to find the error line.
  final Key? errorKey;

  /// Asks the keyboard to capitalize; anything but none also capitalizes
  /// the first letter as typed, which hardware keyboards ignore otherwise.
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    this.fieldKey,
    required this.hintText,
    this.validator,
    this.onChanged,
    this.label,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.controller,
    this.focusNode,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.enable = true,
    this.enableSuggestions = true,
    this.enableIMEPersonalizedLearning = true,
    this.obscureText = false,
    this.enableInteractiveSelection = true,
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
    this.expands = false,
    this.labelLeftPadding,
    this.readOnly = false,
    this.helperText,
    this.helper,
    this.errorText,
    this.errorKey,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isMultiline = maxLines > 1;
    final inputField = TextFormField(
      key: fieldKey,
      autofocus: autofocus ?? false,
      textAlign: TextAlign.start,
      textAlignVertical: isMultiline
          ? TextAlignVertical.top
          : TextAlignVertical.center,
      keyboardType: keyboardType,
      autocorrect: autocorrect ?? !obscureText,
      autofillHints: autofillHints,
      enableSuggestions: enableSuggestions,
      enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
      controller: controller,
      focusNode: focusNode,
      maxLength: maxLength,
      enabled: enable,
      initialValue: initialValue,
      inputFormatters: textCapitalization == TextCapitalization.none
          ? inputFormatters
          : [...inputFormatters, const CapitalizeFirstLetterFormatter()],
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      enableInteractiveSelection: enableInteractiveSelection,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      readOnly: readOnly || onTap != null,
      onTap: onTap,
      mouseCursor: readOnly ? SystemMouseCursors.basic : null,
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
      maxLines: expands ? null : maxLines,
      expands: expands,
      buildCounter:
          (
            context, {
            required currentLength,
            required isFocused,
            required maxLength,
          }) => counter,
      decoration: InputDecoration(
        // borders, hintStyle, contentPadding come from inputDecorationTheme
        filled: true,
        // bg.input = bg.elevated; bg.callout for disabled and read-only
        fillColor: enable && !readOnly ? context.bgElevated : context.bgCallout,
        // Read-only draws no outline; the fill alone marks it.
        enabledBorder: readOnly ? _noBorder : null,
        focusedBorder: readOnly ? _noBorder : null,
        // Read-only neither tints on hover nor shows the text cursor; only
        // its icons react to the pointer.
        hoverColor: readOnly ? Colors.transparent : null,
        hintText: hintText,
        prefixIcon: prefixIcon != null
            ? _buildFix(
                prefixIcon!,
                iconColor: context.textPrimary,
                multilineAlignment: Alignment.topLeft,
              )
            : null,
        prefixIconConstraints: _multilineIconConstraints(),
        suffixIcon: suffixIcon != null
            ? _buildFix(
                suffixIcon!,
                iconColor: context.textPrimary,
                multilineAlignment: Alignment.topRight,
              )
            : null,
      ),
    );

    final under = _under(context);
    // If a label is provided, wrap the input field in a Column with a Text widget above.
    if (label != null) {
      final double resolvedLabelLeftPadding =
          labelLeftPadding ?? (prefixIcon != null ? 16.0 : 8.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: resolvedLabelLeftPadding),
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
          ?under,
        ],
      );
    }

    if (under == null) return inputField;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [inputField, under],
    );
  }

  /// The design's helper line: 16px in from the box, 4px above and below,
  /// label/medium in text/tertiary, or the error color for an error.
  Widget? _under(BuildContext context) {
    final error = errorText;
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(
      color: error != null ? context.statusErrorText : context.textTertiary,
    );
    final Widget? line = error != null
        ? Text(error, key: errorKey)
        : helper ?? (helperText != null ? Text(helperText!) : null);
    if (line == null) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DefaultTextStyle.merge(style: style, child: line),
    );
  }

  Widget _buildFix(
    Object iconPath, {
    Color? iconColor,
    required Alignment multilineAlignment,
  }) {
    final isMultiline = maxLines > 1;
    Widget? appAsset;
    // An icon's 24px with 16px above and below: the field's standard height.
    var inset = 16.h;
    if (iconPath is IconData) {
      appAsset = Icon(iconPath, color: iconColor);
    } else if (iconPath is String) {
      appAsset = AppImage(path: iconPath, color: iconColor);
    } else if (iconPath is Widget) {
      // A widget, such as an IconButton or a text button, keeps that same
      // height: its tap target is held to 32px, in 12px above and below.
      inset = 12.h;
      appAsset = IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(32, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        child: TextButtonTheme(
          data: TextButtonThemeData(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          child: iconPath,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: inset, bottom: inset),
      child: Align(
        alignment: isMultiline ? multilineAlignment : Alignment.center,
        widthFactor: 1.0,
        heightFactor: isMultiline ? null : 1.0,
        child: appAsset,
      ),
    );
  }

  static final _noBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide.none,
  );

  BoxConstraints? _multilineIconConstraints() {
    if (maxLines <= 1) {
      return null;
    }
    final approxLineHeight = 24.h;
    return BoxConstraints(minWidth: 48, minHeight: approxLineHeight * maxLines);
  }
}

/// Capitalizes the first letter of the text as it is typed or pasted. A
/// letter whose capital is more than one character (ß) is left alone.
class CapitalizeFirstLetterFormatter extends TextInputFormatter {
  const CapitalizeFirstLetterFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty || !newValue.composing.isCollapsed) return newValue;
    final first = text.characters.first;
    final upper = first.toUpperCase();
    if (upper == first || upper.length != first.length) return newValue;
    return newValue.copyWith(text: upper + text.substring(first.length));
  }
}
