import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T value)? onChanged;
  final String? label;
  final String? prefixIconPath;

  const AppDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.label,
    this.prefixIconPath,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dropDown = Container(
      padding: EdgeInsets.symmetric(horizontal: 8),
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(
          color: context.borderInput,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (prefixIconPath != null) AppImage(path: prefixIconPath!),
          Expanded(
            child: DropdownButton<T>(
              isExpanded: true,
              padding: EdgeInsets.only(left: prefixIconPath != null ? 8 : 0),
              style: textTheme.bodyMedium!.copyWith(
                color: context.textPrimary,
              ),
              value: value,
              borderRadius: BorderRadius.circular(16),
              underline: const SizedBox.shrink(),
              items: items,
              onChanged: (value) => onChanged?.call(value as T),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
              label!,
              style: textTheme.labelLarge?.copyWith(
                color: context.textSecondary,
                fontSize: 14.sp,
              ),
            ),
          ),
        const SizedBox(height: 4.0),
        dropDown,
      ],
    );
  }
}
