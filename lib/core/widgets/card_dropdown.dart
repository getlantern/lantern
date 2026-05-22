import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';

import '../utils/platform_utils.dart';

class CardDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuEntry<T>> entries;
  final ValueChanged<T?> onChanged;
  final FormFieldValidator<T>? validator;
  final String? hintText;
  final Object? prefixIcon;
  final bool enabled;
  final Key? formFieldKey;

  const CardDropdown({
    super.key,
    required this.value,
    required this.entries,
    required this.onChanged,
    this.validator,
    this.hintText,
    this.prefixIcon,
    this.enabled = true,
    this.formFieldKey,
  });

  Widget? _buildLeading(Object? iconPath, BuildContext context) {
    if (iconPath == null) return null;
    if (iconPath is IconData) {
      return Icon(iconPath, color: context.textPromoIcon);
    } else if (iconPath is String) {
      return AppImage(path: iconPath, color: context.textPromoIcon);
    } else if (iconPath is Widget) {
      return iconPath;
    }
    return null;
  }

  List<DropdownMenuEntry<T>> _withDividers(BuildContext context) {
    final divider = BorderSide(color: context.borderInput, width: 1);
    final itemStyle = ButtonStyle(
      alignment: AlignmentDirectional.centerStart,
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    );
    return [
      for (var i = 0; i < entries.length; i++)
        DropdownMenuEntry<T>(
          value: entries[i].value,
          label: entries[i].label,
          enabled: entries[i].enabled,
          leadingIcon: entries[i].leadingIcon,
          trailingIcon: entries[i].trailingIcon,
          style: itemStyle,
          labelWidget: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: i == entries.length - 1 ? null : Border(bottom: divider),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: defaultSize,
              vertical: PlatformUtils.isDesktop ? defaultSize : 12,
            ),
            alignment: AlignmentDirectional.centerStart,
            child: entries[i].labelWidget ?? Text(entries[i].label),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: color, width: width),
    );

    return FormField<T>(
      key: formFieldKey,
      initialValue: value,
      validator: validator,
      builder: (state) {
        return DropdownMenu<T>(
          key: ValueKey<T?>(state.value),
          initialSelection: state.value,
          enabled: enabled,
          requestFocusOnTap: false,
          enableSearch: false,
          enableFilter: false,
          expandedInsets: EdgeInsets.zero,
          menuHeight: 320,
          hintText: hintText,
          leadingIcon: _buildLeading(prefixIcon, context),
          dropdownMenuEntries: _withDividers(context),
          errorText: state.errorText,
          onSelected: (selected) {
            state.didChange(selected);
            onChanged(selected);
          },
          textStyle: AppTextStyles.bodyMedium.copyWith(
            color: enabled ? context.textPrimary : context.textDisabled,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: enabled
                ? context.bgElevated
                : context.borderInput.withValues(alpha: 0.3),
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: context.textDisabled,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ),
            border: border(context.borderInput, 1),
            enabledBorder: border(context.borderInput, 1),
            focusedBorder: border(context.borderInputFocus, 2),
            errorBorder: border(context.statusErrorBorder, 1.2),
            focusedErrorBorder: border(context.statusErrorBorder, 2),
            disabledBorder: border(
              context.borderInput.withValues(alpha: 0.5),
              1,
            ),
          ),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(context.bgElevated),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: borderRadius,
                side: BorderSide(color: context.borderInput, width: 1),
              ),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            elevation: const WidgetStatePropertyAll(2),
          ),
        );
      },
    );
  }
}
