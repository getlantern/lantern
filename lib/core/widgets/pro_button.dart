import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class ProButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ProButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      label: 'Upgrade to Pro',
      icon: AppImagePaths.crown,
      expanded: true,
      isTaller: true,
      onPressed: onPressed,
    );
  }
}
