import 'package:flutter/material.dart';

import 'app_colors.dart' show AppColors;

class AppDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T value)? onChanged;

  const AppDropdown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.gray3,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButton<T>(
        isExpanded: true,
        padding: EdgeInsets.symmetric(horizontal: 16),
        style: textTheme.bodyMedium!.copyWith(
          color: AppColors.gray9,
        ),
        value: value,
        borderRadius: BorderRadius.circular(16),
        underline: const SizedBox.shrink(),
        items: items,
        onChanged: (value) => onChanged?.call(value as T),
      ),
    );
  }
}
