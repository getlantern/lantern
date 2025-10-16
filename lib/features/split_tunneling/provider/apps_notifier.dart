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

  Future<void> toggleApp(AppData app) async {
    final isEnabled = state.any((a) => a.name == app.name);
    final action =
        isEnabled ? SplitTunnelActionType.remove : SplitTunnelActionType.add;

    final result = isEnabled
        ? await _lanternService.removeSplitTunnelItem(
            getFilterType(), appPath(app))
        : await _lanternService.addSplitTunnelItem(
            getFilterType(), appPath(app));

    if (result.isLeft()) {
      final failure = result.fold((l) => l, (r) => null);
      appLogger.error('Failed to $action item: ${failure?.error}');
    } else {
      state = isEnabled
          ? state.where((a) => a.name != app.name).toSet()
          : {
              ...state,
              app.copyWith(
                isEnabled: true,
              )
            };
      await _db.saveApps(state);
    }
  }

  ///This should be called only for macOS & Android
  SplitTunnelFilterType getFilterType() {
    if (PlatformUtils.isMacOS) {
      return SplitTunnelFilterType.processName;
    }
    return SplitTunnelFilterType.packageName;
  }

  ///For macOS, we need to use regex to match the app path
  ///For other platforms, we can use the bundleId/packageName
  String appPath(AppData appData) {
    if (PlatformUtils.isMacOS) {
      return '${appData.appPath}/Contents/MacOS/.*';
    }
    return appData.bundleId;
  }

  void selectAllApps() async {
    final allApps = (ref.read(appsDataProvider).value ?? [])
        .where((a) => a.iconPath.isNotEmpty || a.iconBytes != null)
        .where((a) => a.name != AppSecrets.lanternPackageName)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final all = allApps.map((a) => appPath(a)).toList();

    final result = await _lanternService.addAllItems(getFilterType(), all);
    result.fold(
      (l) => appLogger.error('Failed to add all apps: ${l.error}'),
      (r) async {
        state = allApps.map((a) => a.copyWith(isEnabled: true)).toSet();
        await _db.saveApps(state);
      },
    );
  }

  void deselectAllApps() async {
    final allApps = state.toList();
    final stringsList = allApps.map((a) => appPath(a)).toList();
    final result =
        await _lanternService.removeAllItems(getFilterType(), stringsList);
    result.fold(
      (l) => appLogger.error('Failed to remove all apps: ${l.error}'),
      (r) async {
        final newApps =
            allApps.map((a) => a.copyWith(isEnabled: false)).toSet();

        await _db.saveApps(newApps);
        state = _db.getEnabledApps();
      },
    );
  }
}
