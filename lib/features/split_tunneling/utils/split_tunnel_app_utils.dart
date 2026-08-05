import 'dart:io';

import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/models/app_data.dart';

String stableAppId(AppData app) {
  if (Platform.isWindows || Platform.isMacOS) {
    return app.appPath;
  }
  return app.bundleId;
}

String normalizedAppId(AppData app) {
  final id = stableAppId(app).trim();
  if (Platform.isWindows) {
    return id.toLowerCase();
  }
  return id;
}

bool isLanternApp(AppData app) {
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

List<AppData> dedupeAndSortApps(
  Iterable<AppData> apps, {
  bool excludeLantern = true,
}) {
  final byId = <String, AppData>{};

  for (final app in apps) {
    if (excludeLantern && isLanternApp(app)) {
      continue;
    }

    final id = normalizedAppId(app);
    if (id.isEmpty) {
      continue;
    }

    byId[id] = pickPreferredAppEntry(byId[id], app);
  }

  final byDisplay = <String, AppData>{};
  for (final app in byId.values) {
    if (Platform.isWindows) {
      final displayKey = _windowsDisplayDedupeKey(app);
      if (displayKey.isNotEmpty) {
        byDisplay[displayKey] = pickPreferredAppEntry(
          byDisplay[displayKey],
          app,
        );
        continue;
      }
    }
    byDisplay[normalizedAppId(app)] = pickPreferredAppEntry(
      byDisplay[normalizedAppId(app)],
      app,
    );
  }

  final out = byDisplay.values.toList()..sort(_compareAppsByDisplayName);
  return out;
}

int _compareAppsByDisplayName(AppData a, AppData b) {
  final aName = a.name.trim();
  final bName = b.name.trim();
  final byFoldedName = aName.toLowerCase().compareTo(bName.toLowerCase());
  if (byFoldedName != 0) {
    return byFoldedName;
  }

  final byName = aName.compareTo(bName);
  if (byName != 0) {
    return byName;
  }

  final byId = normalizedAppId(a).compareTo(normalizedAppId(b));
  if (byId != 0) {
    return byId;
  }
  return a.appPath.compareTo(b.appPath);
}

String _windowsDisplayDedupeKey(AppData app) {
  final name = app.name.trim().toLowerCase();
  if (name.isEmpty) {
    return '';
  }
  return 'name:$name';
}
