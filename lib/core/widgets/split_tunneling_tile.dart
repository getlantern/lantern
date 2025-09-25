import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/common/common.dart';

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
      onPressed: onPressed,
      trailing: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppTextButton(
            underLine: false,
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
