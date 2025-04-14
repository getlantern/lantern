import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class InfoRow extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const InfoRow({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.gray2,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AppImage(
                path: AppImagePaths.info,
                width: 20,
                height: 20,
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: AppTestStyles.bodyMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.43,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
