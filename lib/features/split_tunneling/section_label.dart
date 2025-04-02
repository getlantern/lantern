import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class SectionLabel extends StatelessWidget {
  final String title;
  const SectionLabel(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        title,
        style: AppTestStyles.labelLarge.copyWith(
          color: AppColors.gray8,
        ),
      ),
    );
  }
}
