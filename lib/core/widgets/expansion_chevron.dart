import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';

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
        color: context.textPrimary,
        height: size,
      ),
    );
  }
}

/// Reserves exactly the space [ExpansionChevron] (and the forward arrow on
/// mobile country tiles) occupies, without drawing it. Rows without a chevron
/// use it so their trailing latency labels right-align with rows that have one.
class ChevronPlaceholder extends StatelessWidget {
  final double size;

  const ChevronPlaceholder({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: false,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: AppImage(path: AppImagePaths.arrowForward, height: size),
    );
  }
}
