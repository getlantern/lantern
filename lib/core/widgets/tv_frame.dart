import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/utils/platform_utils.dart';

/// On TVs, renders the portrait phone UI as a centered column instead of
/// stretching it across the landscape screen.
class TvFrame extends StatelessWidget {
  const TvFrame({
    super.key,
    required this.background,
    required this.child,
    this.enabled = true,
  });

  /// Fills the sides so the column reads as part of the app, not a letterbox.
  final Color background;
  final Widget child;

  /// False under the two-panel TV shell, which lays screens out itself.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !PlatformUtils.isTv) return child;
    final mediaQuery = MediaQuery.of(context);
    final width = math.min(mediaQuery.size.width, tvContentMaxWidth);
    return ColoredBox(
      color: background,
      child: Center(
        child: SizedBox(
          width: width,
          child: MediaQuery(
            data: mediaQuery.copyWith(
              size: Size(width, mediaQuery.size.height),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
