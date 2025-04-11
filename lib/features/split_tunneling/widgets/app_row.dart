// Individual app row component
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/models/app_data.dart';

class AppRow extends StatelessWidget {
  final AppData app;
  final VoidCallback? onToggle;

  const AppRow({
    super.key,
    required this.app,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon + App Name
          Row(
            children: [
              if (app.iconPath.isNotEmpty)
                Image.file(
                  File(app.iconPath),
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                )
              else
                Icon(Icons.apps, size: 24, color: AppColors.gray6),
              const SizedBox(width: 12),
              Text(
                app.name.replaceAll(".app", ""),
                style: AppTestStyles.bodyMedium.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.gray9,
                ),
              ),
            ],
          ),
          // Toggle Button
          if (onToggle != null)
            AppIconButton(
              path: app.isEnabled ? AppImagePaths.minus : AppImagePaths.plus,
              onPressed: onToggle!,
            ),
        ],
      ),
    );
  }
}
