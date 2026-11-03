import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/utils/platform_utils.dart' show PlatformUtils;
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'apps_data_provider.dart';

part 'apps_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingApps extends _$SplitTunnelingApps {
  late final LanternService _lanternService = ref.read(lanternServiceProvider);

  @override
  FutureOr<Set<AppData>> build() async {
    final appsAsync = ref.watch(appsDataProvider);

    final installed = appsAsync.maybeWhen(
      data: (v) => v,
      orElse: () => const <AppData>[],
    );

    final type = getFilterType();

    final enabledItemsEither = await _lanternService.getSplitTunnelItems(type);
    return enabledItemsEither.match((f) {
      appLogger.error('Failed to load enabled split-tunnel items: ${f.error}');
      return <AppData>{};
    }, (items) => _enabledApps(installed, items));
  }

  Set<AppData> _enabledApps(Iterable<AppData> installed, List<String> items) {
    if (getFilterType() == SplitTunnelFilterType.processPath) {
      return windowsEnabledApps(installed, items).toSet();
    }
    final enabled = items.toSet();
    return dedupeAndSortApps(installed)
        .where((app) {
          final value = splitTunnelValue(app, logIfEmpty: false);
          return value != null && enabled.contains(value);
        })
        .map((app) => app.copyWith(isEnabled: true))
        .toSet();
  }

  SplitTunnelFilterType getFilterType() {
    if (PlatformUtils.isMacOS) {
      return SplitTunnelFilterType.processPathRegex;
    } else if (PlatformUtils.isWindows) {
      return SplitTunnelFilterType.processPath;
    }
    return SplitTunnelFilterType.packageName;
  }

  String appPath(AppData appData) {
    if (getFilterType() == SplitTunnelFilterType.processPathRegex) {
      return macOSSplitTunnelRule(appData);
    }
    if (getFilterType() == SplitTunnelFilterType.processPath) {
      return appData.appPath;
    }
    return appData.bundleId;
  }

  String? splitTunnelValue(AppData appData, {bool logIfEmpty = true}) {
    final value = appPath(appData).trim();
    if (value.isNotEmpty) {
      return value;
    }
    if (logIfEmpty) {
      appLogger.warning(
        'Skipping split-tunnel update for app with empty identifier: ${normalizedAppId(appData)}',
      );
    }
    return null;
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

  String _appId(AppData app) =>
      getFilterType() == SplitTunnelFilterType.processPath
      ? windowsAppPathId(app.appPath)
      : normalizedAppId(app);

  Set<String> _stateIds() => _current().map(_appId).toSet();

  /// Add one Windows executable without toggling an existing selection off.
  Future<Failure?> addExecutable(String path) async {
    final app = AppData(
      name: p.windows.basename(path),
      bundleId: '',
      appPath: path,
    );
    if (getFilterType() != SplitTunnelFilterType.processPath ||
        !isWindowsExecutablePath(path) ||
        isLanternApp(app)) {
      return Failure(
        error: 'Invalid split-tunnel executable',
        localizedErrorMessage: 'select_windows_executable'.i18n,
      );
    }
    if (_stateIds().contains(_appId(app))) return null;

    final result = await _lanternService.addSplitTunnelItem(
      SplitTunnelFilterType.processPath,
      path,
    );
    final failure = result.match((failure) => failure, (_) => null);
    if (failure != null) return failure;

    // The core may expand a short path. Read back the persisted identity.
    final saved = await _lanternService.getSplitTunnelItems(
      SplitTunnelFilterType.processPath,
    );
    return saved.match((failure) => failure, (paths) {
      if (ref.mounted) {
        state = AsyncData(_enabledApps(_installedAppsSnapshot(), paths));
        ref.invalidateSelf();
      }
      return null;
    });
  }

  Future<void> toggleApp(AppData app) async {
    final id = _appId(app);
    final value = splitTunnelValue(app);
    if (value == null) {
      return;
    }
    final current = _current();
    final isEnabled = current.any((a) => _appId(a) == id);

    final result = isEnabled
        ? await _lanternService.removeSplitTunnelItem(getFilterType(), value)
        : await _lanternService.addSplitTunnelItem(getFilterType(), value);

    await result.match(
      (failure) async {
        appLogger.error(
          'Failed to ${isEnabled ? "remove" : "add"} item: ${failure.error}',
        );
      },
      (_) async {
        final next = isEnabled
            ? current.where((a) => _appId(a) != id).toSet()
            : {...current, app.copyWith(isEnabled: true)};

        state = AsyncData(next);

        ref.invalidateSelf();
      },
    );
  }

  Future<void> selectApps(Iterable<AppData> apps) async {
    final current = _current();
    final currentIds = _stateIds();
    final toAdd = apps.where((a) => !currentIds.contains(_appId(a))).toList();
    if (toAdd.isEmpty) return;

    final validToAdd = <AppData>[];
    final paths = <String>[];
    for (final app in toAdd) {
      final value = splitTunnelValue(app);
      if (value != null) {
        validToAdd.add(app);
        paths.add(value);
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
    final toRemove = apps.where((a) => currentIds.contains(_appId(a))).toList();
    if (toRemove.isEmpty) return;

    final validToRemove = <AppData>[];
    final paths = <String>[];
    for (final app in toRemove) {
      final value = splitTunnelValue(app);
      if (value != null) {
        validToRemove.add(app);
        paths.add(value);
      }
    }

    if (paths.isEmpty) return;

    final result = await _lanternService.removeAllItems(getFilterType(), paths);

    await result.match(
      (l) async => appLogger.error('Failed to remove apps: ${l.error}'),
      (_) async {
        final removeIds = validToRemove.map(_appId).toSet();
        state = AsyncData(
          current.where((a) => !removeIds.contains(_appId(a))).toSet(),
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
