import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/platform_utils.dart' show PlatformUtils;
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';
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

    final filtered = dedupeAndSortApps(installed);

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
            .where((app) {
              final values = splitTunnelValues(app, logIfEmpty: false);
              if (values.isEmpty) {
                return false;
              }
              for (final value in values) {
                if (enabled.contains(value)) {
                  return true;
                }
              }
              return false;
            })
            .map((a) => a.copyWith(isEnabled: true))
            .toSet();
      },
    );
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
    if (PlatformUtils.isWindows) {
      return appData.appPath;
    }
    if (PlatformUtils.isMacOS) {
      return appData.appPath;
    }
    return appData.bundleId;
  }

  List<String> splitTunnelValues(AppData appData, {bool logIfEmpty = true}) {
    final value = appPath(appData).trim();
    if (value.isEmpty) {
      if (logIfEmpty) {
        appLogger.warning(
          'Skipping split-tunnel update for app with empty identifier: ${normalizedAppId(appData)}',
        );
      }
      return const <String>[];
    }

    if (!PlatformUtils.isMacOS) {
      return <String>[value];
    }

    final bundlePath = value.replaceAll(RegExp(r'[\\/]+$'), '');
    final escapedBundlePath = RegExp.escape(bundlePath);

    // Primary format uses escaped bundle path. The legacy unescaped format is
    // included so remove/match works for existing persisted rules.
    return <String>[
      '$escapedBundlePath/Contents/.*',
      '$bundlePath/Contents/.*',
    ];
  }

  String? splitTunnelValue(AppData appData, {bool logIfEmpty = true}) {
    final values = splitTunnelValues(appData, logIfEmpty: logIfEmpty);
    if (values.isEmpty) {
      return null;
    }
    return values.first;
  }

  List<AppData> _installedAppsSnapshot() {
    final apps = ref.read(appsDataProvider);

    final allApps = apps.maybeWhen(
      data: (v) => v,
      orElse: () => const <AppData>[],
    );

    return dedupeAndSortApps(allApps);
  }

  Set<AppData> _current() => state.value ?? <AppData>{};

  Set<String> _stateIds() => _current().map(normalizedAppId).toSet();

  Future<void> toggleApp(AppData app) async {
    final id = normalizedAppId(app);
    final values = splitTunnelValues(app);
    if (values.isEmpty) {
      return;
    }
    final primaryValue = values.first;

    final current = _current();
    final isEnabled = current.any((a) => normalizedAppId(a) == id);

    final result = isEnabled
        ? await _lanternService.removeAllItems(getFilterType(), values)
        : await _lanternService.addSplitTunnelItem(
            getFilterType(),
            primaryValue,
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
            ? current.where((a) => normalizedAppId(a) != id).toSet()
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
        .where((a) => !currentIds.contains(normalizedAppId(a)))
        .toList();
    if (toAdd.isEmpty) return;

    final validToAdd = <AppData>[];
    final paths = <String>[];
    for (final app in toAdd) {
      final values = splitTunnelValues(app);
      if (values.isNotEmpty) {
        validToAdd.add(app);
        paths.add(values.first);
      }
    }

    if (paths.isEmpty) return;

    final result = await _lanternService.addAllItems(getFilterType(), paths);

    await result.match(
      (l) async => appLogger.error('Failed to add apps: ${l.error}'),
      (_) async {
        state = AsyncData({
          ...current,
          ...validToAdd.map((a) => a.copyWith(isEnabled: true)),
        });

        ref.invalidateSelf();
      },
    );
  }

  Future<void> deselectApps(Iterable<AppData> apps) async {
    final current = _current();
    final currentIds = _stateIds();
    final toRemove = apps
        .where((a) => currentIds.contains(normalizedAppId(a)))
        .toList();
    if (toRemove.isEmpty) return;

    final validToRemove = <AppData>[];
    final paths = <String>[];
    for (final app in toRemove) {
      final values = splitTunnelValues(app);
      if (values.isNotEmpty) {
        validToRemove.add(app);
        paths.addAll(values);
      }
    }

    if (paths.isEmpty) return;

    final result = await _lanternService.removeAllItems(getFilterType(), paths);

    await result.match(
      (l) async => appLogger.error('Failed to remove apps: ${l.error}'),
      (_) async {
        final removeIds = validToRemove.map(normalizedAppId).toSet();
        state = AsyncData(
          current.where((a) => !removeIds.contains(normalizedAppId(a))).toSet(),
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
