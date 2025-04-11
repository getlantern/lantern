import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_tile.dart';

class SplitTunnelingTile extends StatelessWidget {
  final String label;
  final String actionText;
  final VoidCallback onPressed;
  final String? subtitle;
  final Object? icon;

  const SplitTunnelingTile({
    super.key,
    required this.label,
    required this.actionText,
    required this.onPressed,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppTile(
      label: label,
      icon: icon,
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTestStyles.labelMedium.copyWith(
                color: AppColors.gray7,
              ),
            )
          : null,
      onPressed: () => appRouter.push(WebsiteSplitTunneling()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppTextButton(
            label: actionText,
            onPressed: onPressed,
          ),
          AppImage(
            path: AppImagePaths.arrowForward,
            height: 20,
          ),
        ],
      ),
    );
  }
}
