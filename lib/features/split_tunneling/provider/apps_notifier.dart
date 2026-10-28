import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'apps_data_provider.dart';

part 'apps_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplitTunnelingApps extends _$SplitTunnelingApps {
  @override
  FutureOr<Set<AppData>> build() async {
    final installed = ref.watch(appsDataProvider).value ?? const <AppData>[];
    final snapshot = await ref.watch(splitTunnelProvider.future);
    return storedSplitTunnelApps(snapshot, installed).toSet();
  }

  SplitTunnelFilterType getFilterType() {
    if (PlatformUtils.isMacOS) return SplitTunnelFilterType.processPathRegex;
    if (PlatformUtils.isWindows) return SplitTunnelFilterType.processPath;
    return SplitTunnelFilterType.packageName;
  }

  String appPath(AppData app) => switch (getFilterType()) {
    SplitTunnelFilterType.processPathRegex => macOSSplitTunnelRule(app),
    SplitTunnelFilterType.processPath => app.appPath,
    _ => app.bundleId,
  };

  Future<Failure?> toggleApp(AppData app) {
    if (app is StoredSplitTunnelApp) {
      return ref
          .read(splitTunnelProvider.notifier)
          .setSelector(app.selectorType, app.selector, selected: false);
    }
    final value = appPath(app).trim();
    if (value.isEmpty) return Future.value(_invalidApp());
    return ref
        .read(splitTunnelProvider.notifier)
        .setSelector(getFilterType(), value);
  }

  Future<Failure?> addExecutable(String path) {
    final app = AppData(
      name: p.windows.basename(path),
      bundleId: '',
      appPath: path,
    );
    if (getFilterType() != SplitTunnelFilterType.processPath ||
        !isWindowsExecutablePath(path) ||
        isLanternApp(app)) {
      return Future.value(_invalidApp());
    }
    final selected =
        ref
            .read(splitTunnelProvider)
            .value
            ?.selectors(SplitTunnelFilterType.processPath) ??
        const <String>[];
    if (selected.any(
      (value) => windowsAppPathId(value) == windowsAppPathId(path),
    )) {
      return Future.value();
    }
    return ref
        .read(splitTunnelProvider.notifier)
        .setSelector(SplitTunnelFilterType.processPath, path, selected: true);
  }

  Failure _invalidApp() => Failure(
    error: 'Invalid split-tunnel executable',
    localizedErrorMessage: 'select_windows_executable'.i18n,
  );

  Future<Failure?> deselectAllApps() =>
      ref.read(splitTunnelProvider.notifier).clearApps();
}
