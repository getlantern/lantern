import 'dart:io';

import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:path/path.dart' as p;

String stableAppId(AppData app) {
  if (Platform.isWindows || Platform.isMacOS) {
    return app.appPath;
  }
  return app.bundleId;
}

class StoredSplitTunnelApp extends AppData {
  StoredSplitTunnelApp(this.selectorType, this.selector, AppData metadata)
    : super(
        name: metadata.name,
        bundleId: metadata.bundleId,
        appPath: metadata.appPath,
        iconPath: metadata.iconPath,
        iconBytes: metadata.iconBytes,
        isBrowser: metadata.isBrowser,
        wrappedBundle: metadata.wrappedBundle,
        isEnabled: true,
      );

  final SplitTunnelFilterType selectorType;
  final String selector;
}

String splitTunnelAppRowId(AppData app) => app is StoredSplitTunnelApp
    ? '${app.selectorType.value}:${app.selector}'
    : normalizedAppId(app);

List<AppData> storedSplitTunnelApps(
  SplitTunnelState snapshot,
  Iterable<AppData> installed,
) {
  final result = <AppData>[];
  for (final type in SplitTunnelState.appTypes) {
    final selectors = snapshot.appSelectors(type);
    if (selectors.isEmpty) continue;
    final bySelector = <String, AppData>{};
    for (final app in installed) {
      final selector = _appSelector(type, app);
      bySelector[selector] = pickPreferredAppEntry(bySelector[selector], app);
    }
    for (final selector in selectors) {
      final key =
          type == SplitTunnelFilterType.processPath && Platform.isWindows
          ? windowsAppPathId(selector)
          : selector;
      var metadata = bySelector[key];
      final name = selector
          .replaceFirst(RegExp(r'/Contents/\.\*$'), '')
          .split(RegExp(r'[\\/]+'))
          .last;
      metadata ??= AppData(
        name: name.isEmpty ? selector : name,
        bundleId: type == SplitTunnelFilterType.packageName ? selector : '',
        appPath: type == SplitTunnelFilterType.packageName ? '' : selector,
      );
      result.add(StoredSplitTunnelApp(type, selector, metadata));
    }
  }
  return result
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

// What a saved selector of [type] looks like for [app].
String _appSelector(SplitTunnelFilterType type, AppData app) => switch (type) {
  SplitTunnelFilterType.packageName => app.bundleId,
  SplitTunnelFilterType.processPath =>
    Platform.isWindows ? windowsAppPathId(app.appPath) : app.appPath,
  SplitTunnelFilterType.processPathRegex => macOSSplitTunnelRule(app),
  _ => app.appPath.split(RegExp(r'[\\/]+')).last,
};

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

AppData windowsExecutableApp(String path, Iterable<AppData> installed) {
  final id = windowsAppPathId(path);
  AppData? metadata;
  for (final app in installed) {
    if (windowsAppPathId(app.appPath) == id) {
      metadata = pickPreferredAppEntry(metadata, app);
    }
  }
  return metadata ??
      AppData(name: p.windows.basename(path), bundleId: '', appPath: path);
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

  return byId.values.toList()..sort(_compareAppsByDisplayName);
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
///
/// Safari's requests are sent by the system WebKit networking process, which
/// runs outside Safari.app, so its rule covers that process too. Web views in
/// other apps use the same process and follow Safari's rule.
String macOSSplitTunnelRule(AppData app) {
  if (app.wrappedBundle.isNotEmpty) {
    return '/Wrapper/${RegExp.escape(app.wrappedBundle)}/.*';
  }
  final bundle = '${app.appPath}/Contents/.*';
  return app.bundleId == 'com.apple.Safari'
      ? '$_webKitNetworking/Contents/.*|$bundle'
      : bundle;
}

const _webKitNetworking =
    r'/System/Library/Frameworks/WebKit\.framework/.*/com\.apple\.WebKit\.Networking\.xpc';

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
