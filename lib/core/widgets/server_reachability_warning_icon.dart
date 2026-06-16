import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

/// Warning icon shown when a server may be unreachable. Renders an info icon
/// with a tooltip and accessibility label.
class ServerReachabilityWarningIcon extends StatelessWidget {
  const ServerReachabilityWarningIcon({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final label = 'server_may_be_unreachable'.i18n;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: AppImage(
          path: AppImagePaths.info,
          height: size,
          width: size,
          color: context.statusWarningBgDot,
        ),
      ),
    );
  }
}
