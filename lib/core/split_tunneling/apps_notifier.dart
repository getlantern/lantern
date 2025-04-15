import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/split_tunneling/split_tunnel_filer_type.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apps_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingApps extends _$SplitTunnelingApps {
  late final LocalStorageService _db;
  late final LanternService _lanternService;

  @override
  Set<AppData> build() {
    _db = sl<LocalStorageService>();
    final apps = _db.getEnabledApps();
    _lanternService = ref.read(lanternServiceProvider);
    return apps;
  }

  // Toggle app selection for split tunneling
  Future<void> toggleApp(AppData app) async {
    final isEnabled = state.any((a) => a.name == app.name);
    final action =
        isEnabled ? SplitTunnelActionType.remove : SplitTunnelActionType.add;
    final result = isEnabled
        ? await _lanternService.removeSplitTunnelItem(
            SplitTunnelFilterType.packageName, app.bundleId)
        : await _lanternService.addSplitTunnelItem(
            SplitTunnelFilterType.packageName, app.bundleId);
    result.match(
      (failure) {
        appLogger.error('Failed to $action item: ${failure.error}');
      },
      (_) {
        state = isEnabled
            ? state.where((a) => a.name != app.name).toSet()
            : {
                ...state,
                app.copyWith(
                  isEnabled: true,
                )
              };
        _db.saveApps(state);
      },
    );
  }
}
