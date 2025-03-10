import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class InfoRow extends StatelessWidget {
  final String text;
  const InfoRow({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              right: 16.0,
            ),
            child: AppImage(
              path: AppImagePaths.info,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTestStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
