import 'package:flutter/material.dart';

import '../common/common.dart';

class PlatformCard extends StatelessWidget {

  final String imagePath;
  final VoidCallback onPressed;
  const PlatformCard({super.key, required this.imagePath, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AppCard(
        padding: const EdgeInsets.all(20.0),
        child: AppImage(path: imagePath),
      ),
    );
  }
}
