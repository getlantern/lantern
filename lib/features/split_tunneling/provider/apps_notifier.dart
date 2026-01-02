import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/app_secrets.dart';
import 'package:lantern/core/models/entity/app_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/platform_utils.dart' show PlatformUtils;
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'apps_data_provider.dart';

part 'apps_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingApps extends _$SplitTunnelingApps {
  final LocalStorageService _db = sl<LocalStorageService>();
  late final LanternService _lanternService = ref.read(lanternServiceProvider);

  @override
  Set<AppData> build() {
    return _db.getEnabledApps();
  }

  // Stable identity per platform
  String _id(AppData a) {
    if (PlatformUtils.isWindows) return a.appPath;
    if (PlatformUtils.isMacOS) return a.appPath;
    return a.bundleId;
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

  bool _shouldRequireIcons() =>
      PlatformUtils.isAndroid || PlatformUtils.isMacOS;

  List<AppData> _installedAppsSnapshot() {
    final apps = ref.read(appsDataProvider);

    final allApps = apps.maybeWhen(
      data: (v) => v,
      orElse: () => const <AppData>[],
    );

    return allApps
        .where((a) {
          if (_shouldRequireIcons()) {
            return a.iconPath.isNotEmpty || a.iconBytes != null;
          }
          return true;
        })
        .where((a) => a.bundleId != AppSecrets.lanternPackageName)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Set<String> _stateIds() => state.map(_id).toSet();

  Future<void> toggleApp(AppData app) async {
    final id = _id(app);
    final isEnabled = state.any((a) => _id(a) == id);

    final result = isEnabled
        ? await _lanternService.removeSplitTunnelItem(
            getFilterType(), appPath(app))
        : await _lanternService.addSplitTunnelItem(
            getFilterType(), appPath(app));

    result.match(
      (failure) => appLogger.error(
          'Failed to ${isEnabled ? "remove" : "add"} item: ${failure.error}'),
      (_) async {
        if (isEnabled) {
          state = state.where((a) => _id(a) != id).toSet();
        } else {
          state = {...state, app.copyWith(isEnabled: true)};
        }
        await _db.saveApps(state);
      },
    );
  }

  /// Select exactly these apps
  Future<void> selectApps(Iterable<AppData> apps) async {
    final currentIds = _stateIds();

    final toAdd = apps.where((a) => !currentIds.contains(_id(a))).toList();

    if (toAdd.isEmpty) return;

    final paths = toAdd.map(appPath).toList();
    final result = await _lanternService.addAllItems(getFilterType(), paths);

    result.match(
      (l) => appLogger.error('Failed to add apps: ${l.error}'),
      (_) async {
        state = {
          ...state,
          ...toAdd.map((a) => a.copyWith(isEnabled: true)),
        };
        await _db.saveApps(state);
      },
    );
  }

  /// Deselect exactly these apps
  Future<void> deselectApps(Iterable<AppData> apps) async {
    final currentIds = _stateIds();

    final toRemove = apps.where((a) => currentIds.contains(_id(a))).toList();

    if (toRemove.isEmpty) return;

    final paths = toRemove.map(appPath).toList();
    final result = await _lanternService.removeAllItems(getFilterType(), paths);

    result.match(
      (l) => appLogger.error('Failed to remove apps: ${l.error}'),
      (_) async {
        final removeIds = toRemove.map(_id).toSet();
        state = state.where((a) => !removeIds.contains(_id(a))).toSet();
        await _db.saveApps(state);
      },
    );
  }

  Future<void> selectAllApps() async {
    await selectApps(_installedAppsSnapshot());
  }

  Future<void> deselectAllApps() async {
    final enabled = state.toList();
    if (enabled.isEmpty) return;
    await deselectApps(enabled);
  }
}
