import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';

Widget? serverReachabilityWarningIcon(
  BuildContext context,
  Server server, {
  double size = 18,
}) {
  if (!server.shouldWarnBeforeManualSelection) return null;
  return serverReachabilityIcon(context, size: size);
}

Widget serverReachabilityIcon(BuildContext context, {double size = 18}) {
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
