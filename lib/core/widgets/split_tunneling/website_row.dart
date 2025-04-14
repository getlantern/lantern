import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/widgets/app_tile.dart';

class WebsiteRow extends StatelessWidget {
  final Website website;
  final VoidCallback onToggle;

  const WebsiteRow({
    super.key,
    required this.website,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppTile(
      label: website.domain,
      tileTextStyle: AppTestStyles.labelLarge.copyWith(
        color: AppColors.gray8,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      trailing: AppIconButton(
        path: AppImagePaths.close,
        onPressed: onToggle,
      ),
    );
  }
}
