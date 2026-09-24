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

/// Regex the core matches against a connection's executable path on macOS.
///
/// Native apps run from inside their bundle, e.g.
/// `/Applications/Firefox.app/Contents/MacOS/firefox`, or from a helper such as
/// `/Applications/Slack.app/Contents/Frameworks/.../Browser Helper`, so the
/// bundle path plus `/Contents/` covers them.
///
/// iPhone and iPad apps are different: macOS mounts `<App>.app/Wrapper` at a
/// random per-app path under /private/var/folders and runs
/// `.../Wrapper/<Inner>.app/<Inner>` from there, so the bundle path never
/// appears in the process path. The `/Wrapper/<Inner>.app/` segment is the
/// stable part, so that is what we match.
String macOSSplitTunnelRule(AppData app) {
  if (app.wrappedBundle.isNotEmpty) {
    return '/Wrapper/${RegExp.escape(app.wrappedBundle)}/.*';
  }
  return '${app.appPath}/Contents/.*';
}

/// Bucket used by the alphabet index for names that do not start with A-Z.
const otherAppsIndexLetter = '#';

/// Letters shown by the alphabet index, in display order.
const alphabetIndexLetters = [
  otherAppsIndexLetter, //
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', //
];

/// Index letter for [app]: its uppercased first character when that is A-Z,
/// otherwise [otherAppsIndexLetter].
String appIndexLetter(AppData app) {
  final name = app.name.trim();
  if (name.isEmpty) {
    return otherAppsIndexLetter;
  }
  final first = String.fromCharCode(name.runes.first).toUpperCase();
  final code = first.codeUnitAt(0);
  final isAsciiLetter = code >= 0x41 && code <= 0x5A;
  return isAsciiLetter ? first : otherAppsIndexLetter;
}

/// [apps] grouped by index letter, keyed in [alphabetIndexLetters] order and
/// containing only letters that have at least one app.
Map<String, List<AppData>> groupAppsByLetter(Iterable<AppData> apps) {
  final byLetter = <String, List<AppData>>{};
  for (final app in apps) {
    byLetter.putIfAbsent(appIndexLetter(app), () => []).add(app);
  }
  return {
    for (final letter in alphabetIndexLetters)
      if (byLetter.containsKey(letter)) letter: byLetter[letter]!,
  };
}
