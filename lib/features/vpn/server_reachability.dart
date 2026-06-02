import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';

Widget? serverReachabilitySubtitle(
  BuildContext context,
  Server server,
  TextStyle style,
) {
  final parts = <String>[
    if (server.type.isNotEmpty) server.type.capitalize,
    if (server.shouldWarnBeforeManualSelection)
      'server_may_be_unreachable'.i18n,
  ];
  if (parts.isEmpty) return null;

  return Text(
    parts.join(' - '),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: style.copyWith(
      color: server.shouldWarnBeforeManualSelection
          ? context.statusWarningText
          : context.textTertiary,
    ),
  );
}

Widget? serverReachabilityWarningIcon(BuildContext context, Server server) {
  if (!server.shouldWarnBeforeManualSelection) return null;
  return serverReachabilityIcon(context);
}

Widget serverReachabilityIcon(BuildContext context) {
  final label = 'server_may_be_unreachable'.i18n;
  return Tooltip(
    message: label,
    child: Semantics(
      label: label,
      child: AppImage(
        path: AppImagePaths.warning,
        height: 18,
        width: 18,
        color: context.statusWarningText,
      ),
    ),
  );
}
