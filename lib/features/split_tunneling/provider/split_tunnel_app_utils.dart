import 'dart:io';

import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/models/app_data.dart';

String splitTunnelStableAppId(AppData app) {
  if (Platform.isWindows || Platform.isMacOS) {
    return app.appPath;
  }
  return app.bundleId;
}

String splitTunnelNormalizedAppId(AppData app) {
  final id = splitTunnelStableAppId(app).trim();
  if (Platform.isWindows) {
    return id.toLowerCase();
  }
  return id;
}

bool isLanternSplitTunnelApp(AppData app) {
  final packageName = AppSecrets.lanternPackageName.toLowerCase();
  final bundleId = app.bundleId.trim().toLowerCase();
  final appName = app.name.trim().toLowerCase();
  final appPath = app.appPath.trim().toLowerCase();
  final appExe = appPath.split(RegExp(r'[\\/]+')).last;

  return bundleId == packageName ||
      appName == 'lantern' ||
      appExe == 'lantern' ||
      appExe == 'lantern.exe';
}

AppData pickPreferredAppEntry(AppData? current, AppData candidate) {
  if (current == null) {
    return candidate;
  }

  final currentHasIcon =
      (current.iconBytes?.isNotEmpty ?? false) || current.iconPath.isNotEmpty;
  final candidateHasIcon =
      (candidate.iconBytes?.isNotEmpty ?? false) ||
      candidate.iconPath.isNotEmpty;

  if (candidateHasIcon && !currentHasIcon) {
    return candidate;
  }
  if (currentHasIcon && !candidateHasIcon) {
    return current;
  }
  if (candidate.lastUpdateTime > current.lastUpdateTime) {
    return candidate;
  }
  if (current.name.trim().isEmpty && candidate.name.trim().isNotEmpty) {
    return candidate;
  }
  return current;
}

List<AppData> dedupeAndSortSplitTunnelApps(
  Iterable<AppData> apps, {
  bool excludeLantern = true,
}) {
  final byId = <String, AppData>{};

  for (final app in apps) {
    if (excludeLantern && isLanternSplitTunnelApp(app)) {
      continue;
    }

    final id = splitTunnelNormalizedAppId(app);
    if (id.isEmpty) {
      continue;
    }

    byId[id] = pickPreferredAppEntry(byId[id], app);
  }

  final out = byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  return out;
}
