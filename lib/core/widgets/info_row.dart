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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AppIconButton(
              path: AppImagePaths.info,
              onPressed: onPressed,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTestStyles.bodyMedium.copyWith(
                color: AppColors.logTextColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.43,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
