import 'dart:io';

import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:path/path.dart' as p;

String stableAppId(AppData app) {
  if (Platform.isWindows || Platform.isMacOS) {
    return app.appPath;
  }
  return app.bundleId;
}

String normalizedAppId(AppData app) {
  final id = stableAppId(app).trim();
  if (Platform.isWindows) {
    return windowsAppPathId(id);
  }
  return id;
}

/// Windows executable paths are case-insensitive and may use either separator.
String windowsAppPathId(String path) {
  final value = path.trim();
  return value.isEmpty ? '' : p.windows.normalize(value).toLowerCase();
}

/// Accepts drive-qualified .exe paths, excluding device and stream syntax.
bool isWindowsExecutablePath(String path) =>
    RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(path) &&
    !RegExp(r'[\x00-\x1f:<>"|?*]').hasMatch(path.substring(2)) &&
    p.windows.extension(path).toLowerCase() == '.exe';

/// Keep saved executable rules visible even when app discovery misses them.
List<AppData> windowsEnabledApps(
  Iterable<AppData> installed,
  Iterable<String> paths,
) {
  final byPath = <String, AppData>{};
  for (final app in installed) {
    if (app.appPath.trim().isEmpty) continue;
    final id = windowsAppPathId(app.appPath);
    byPath[id] = pickPreferredAppEntry(byPath[id], app);
  }
  final enabled = <String, AppData>{};
  for (final path in paths) {
    if (path.trim().isEmpty) continue;
    final id = windowsAppPathId(path);
    final app =
        byPath[id] ??
        AppData(name: p.windows.basename(path), bundleId: '', appPath: path);
    // Use the stored path for removal, including any native normalization.
    enabled[id] = app.copyWith(appPath: path, isEnabled: true);
  }
  return enabled.values.toList()..sort(_compareAppsByDisplayName);
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

  final out = byId.values.toList()..sort(_compareAppsByDisplayName);
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
  final code = name.runes.first;
  final isAsciiLetter =
      (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A);
  return isAsciiLetter
      ? String.fromCharCode(code).toUpperCase()
      : otherAppsIndexLetter;
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
