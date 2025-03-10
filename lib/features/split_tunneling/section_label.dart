import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';

class SectionLabel extends StatelessWidget {
  final String title;
  const SectionLabel(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        title,
        style: theme.labelLarge!.copyWith(
          color: AppColors.gray8,
        ),
      ),
    );
  }
}
