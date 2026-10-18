import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/utils/platform_utils.dart';

/// On TVs, renders the portrait phone UI as a centered column instead of
/// stretching it across the landscape screen.
class TvFrame extends StatelessWidget {
  const TvFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isTv) return child;
    final mediaQuery = MediaQuery.of(context);
    final width = math.min(mediaQuery.size.width, tvContentMaxWidth);
    return ColoredBox(
      color: Colors.black,
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
