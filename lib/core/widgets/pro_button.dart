import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class ProButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String? label;

  const ProButton({
    super.key,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: label ?? 'upgrade_to_pro'.i18n,
      icon: AppImagePaths.crown,
      expanded: true,
      isTaller: true,
      onPressed: onPressed,
    );
  }
}
