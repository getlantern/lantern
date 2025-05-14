import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'apps_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingApps extends _$SplitTunnelingApps {
  final LocalStorageService _db = sl<LocalStorageService>();
  late final LanternService _lanternService = ref.read(lanternServiceProvider);

  @override
  Set<AppData> build() {
    return _db.getEnabledApps();
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
      (_) async {
        state = isEnabled
            ? state.where((a) => a.name != app.name).toSet()
            : {
                ...state,
                app.copyWith(
                  isEnabled: true,
                )
              };
        await _db.saveApps(state);
      },
    );
  }
}
