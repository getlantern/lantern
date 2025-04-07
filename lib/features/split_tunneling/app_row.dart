// Individual app row component
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/widgets/app_tile.dart';

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
    return AppTile(
      label: app.name.replaceAll(".app", ""),
      tileTextStyle: AppTestStyles.labelLarge.copyWith(
        color: AppColors.gray8,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      icon: app.iconPath.isNotEmpty
          ? Image.file(File(app.iconPath), width: 24, height: 24)
          : Icon(Icons.apps),
      trailing: onToggle != null
          ? AppIconButton(
              path: app.isEnabled ? AppImagePaths.minus : AppImagePaths.plus,
              onPressed: () => onToggle!(),
            )
          : null,
    );
  }
}
