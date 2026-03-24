import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/platform_utils.dart' show PlatformUtils;
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'apps_data_provider.dart';

part 'apps_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingApps extends _$SplitTunnelingApps {
  late final LanternService _lanternService = ref.read(lanternServiceProvider);

  @override
  FutureOr<Set<AppData>> build() async {
    // Rebuild when installed apps list changes
    final appsAsync = ref.watch(appsDataProvider);

    final installed = appsAsync.maybeWhen(
      data: (v) => v,
      orElse: () => const <AppData>[],
    );

    final filtered = _dedupeApps(installed);

    if (filtered.isEmpty) return <AppData>{};

    final type = getFilterType();

    final enabledItemsEither = await _lanternService.getSplitTunnelItems(type);
    return enabledItemsEither.match(
      (f) {
        appLogger.error(
          'Failed to load enabled split-tunnel items: ${f.error}',
        );
        return <AppData>{};
      },
      (items) {
        final enabled = items.toSet();
        return filtered
            .where((a) => enabled.contains(appPath(a)))
            .map((a) => a.copyWith(isEnabled: true))
            .toSet();
      },
    );
  }

  // Stable identity per platform
  String _id(AppData a) {
    if (PlatformUtils.isWindows) return a.appPath;
    if (PlatformUtils.isMacOS) return a.appPath;
    return a.bundleId;
  }

  String _normalizedId(AppData a) {
    final id = _id(a).trim();
    if (PlatformUtils.isWindows) {
      return id.toLowerCase();
    }
    return id;
  }

  bool _isLanternApp(AppData app) {
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

  AppData _preferRicherApp(AppData? current, AppData candidate) {
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

  List<AppData> _dedupeApps(Iterable<AppData> apps) {
    final byId = <String, AppData>{};
    for (final app in apps) {
      if (_isLanternApp(app)) {
        continue;
      }
      final id = _normalizedId(app);
      if (id.isEmpty) {
        continue;
      }
      byId[id] = _preferRicherApp(byId[id], app);
    }

    final out = byId.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// Only called by macOS and Android
  SplitTunnelFilterType getFilterType() {
    if (PlatformUtils.isMacOS) {
      return SplitTunnelFilterType.processPathRegex;
    } else if (PlatformUtils.isWindows) {
      return SplitTunnelFilterType.processPath;
    }
    return SplitTunnelFilterType.packageName;
  }

  /// For macOS, we need to use regex to match the app path
  /// For other platforms, we can use the bundleId/packageName
  String appPath(AppData appData) {
    if (PlatformUtils.isMacOS) {
      // Note that typically MacOS apps use the binary inside the .app bundle
      // at, for example, /Applications/Firefox.app/Contents/MacOS/firefox.
      // Some apps, however, use a helper binary inside the Frameworks folder
      // at, for example:
      // /Applications/Slack.app/Contents/Frameworks/ArcCore.framework/Versions/A/Helpers/Browser Helper.app/Contents/MacOS/Browser Helper
      return '${appData.appPath}/Contents/.*';
    }
    if (PlatformUtils.isWindows) {
      return appData.appPath;
    }
    return appData.bundleId;
  }

  List<AppData> _installedAppsSnapshot() {
    final apps = ref.read(appsDataProvider);

    final allApps = apps.maybeWhen(
      data: (v) => v,
      orElse: () => const <AppData>[],
    );

    return _dedupeApps(allApps);
  }

  Set<AppData> _current() => state.value ?? <AppData>{};

  Set<String> _stateIds() => _current().map(_normalizedId).toSet();

  Future<void> toggleApp(AppData app) async {
    final id = _normalizedId(app);
    final current = _current();
    final isEnabled = current.any((a) => _normalizedId(a) == id);

    final result = isEnabled
        ? await _lanternService.removeSplitTunnelItem(
            getFilterType(),
            appPath(app),
          )
        : await _lanternService.addSplitTunnelItem(
            getFilterType(),
            appPath(app),
          );

    await result.match(
      (failure) async {
        appLogger.error(
          'Failed to ${isEnabled ? "remove" : "add"} item: ${failure.error}',
        );
      },
      (_) async {
        // Optional optimistic UI update
        final next = isEnabled
            ? current.where((a) => _normalizedId(a) != id).toSet()
            : {...current, app.copyWith(isEnabled: true)};

        state = AsyncData(next);

        // Re-sync from lantern-core (authoritative)
        ref.invalidateSelf();
      },
    );
  }

  /// Select exactly these apps
  Future<void> selectApps(Iterable<AppData> apps) async {
    final current = _current();
    final currentIds = _stateIds();
    final toAdd = apps
        .where((a) => !currentIds.contains(_normalizedId(a)))
        .toList();
    if (toAdd.isEmpty) return;

    final paths = toAdd.map(appPath).toList();
    final result = await _lanternService.addAllItems(getFilterType(), paths);

    await result.match(
      (l) async => appLogger.error('Failed to add apps: ${l.error}'),
      (_) async {
        state = AsyncData({
          ...current,
          ...toAdd.map((a) => a.copyWith(isEnabled: true)),
        });

        ref.invalidateSelf();
      },
    );
  }

  Future<void> deselectApps(Iterable<AppData> apps) async {
    final current = _current();
    final currentIds = _stateIds();
    final toRemove = apps
        .where((a) => currentIds.contains(_normalizedId(a)))
        .toList();
    if (toRemove.isEmpty) return;

    final paths = toRemove.map(appPath).toList();
    final result = await _lanternService.removeAllItems(getFilterType(), paths);

    await result.match(
      (l) async => appLogger.error('Failed to remove apps: ${l.error}'),
      (_) async {
        final removeIds = toRemove.map(_normalizedId).toSet();
        state = AsyncData(
          current.where((a) => !removeIds.contains(_normalizedId(a))).toSet(),
        );

        ref.invalidateSelf();
      },
    );
  }

  Future<void> selectAllApps() async {
    await selectApps(_installedAppsSnapshot());
  }

  Future<void> deselectAllApps() async {
    final enabled = _current().toList();
    if (enabled.isEmpty) return;
    await deselectApps(enabled);
  }
}
