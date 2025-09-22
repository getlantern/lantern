import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';

class SectionLabel extends StatelessWidget {
  final String title;

  const SectionLabel(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
              color: AppColors.gray8,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
