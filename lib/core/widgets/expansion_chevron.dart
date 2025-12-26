import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';

import '../common/app_image_paths.dart';

class ExpansionChevron extends StatelessWidget {
  final bool isExpanded;
  final Duration duration;
  final double expandedTurns;
  final double collapsedTurns;
  final double size;

  const ExpansionChevron({
    super.key,
    required this.isExpanded,
    this.duration = const Duration(milliseconds: 200),
    this.expandedTurns = 0.25,
    this.collapsedTurns = 0.0,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      duration: duration,
      turns: isExpanded ? expandedTurns : collapsedTurns,
      child: AppImage(
        path: AppImagePaths.arrowForward,
        height: size,
      ),
    );
  }
}
