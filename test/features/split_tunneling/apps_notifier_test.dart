import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/features/split_tunneling/utils/split_tunnel_app_utils.dart';

class _WindowsApps extends SplitTunnelingApps {
  @override
  SplitTunnelFilterType getFilterType() => SplitTunnelFilterType.processPath;
}

SplitTunnelState _state(List<String> paths) => SplitTunnelState(
  enabled: true,
  policy: SplitTunnelPolicy.bypass,
  filters: {SplitTunnelFilterType.processPath: paths},
);

class _Core extends SplitTunnel {
  _Core(this.paths);

  final List<String> paths;
  final added = <String>[];
  final removed = <String>[];
  Failure? failure;

  @override
  Future<SplitTunnelState> build() async => _state(paths);

  @override
  Future<Failure?> setSelector(
    SplitTunnelFilterType type,
    String value, {
    bool? selected,
  }) async {
    expect(type, SplitTunnelFilterType.processPath);
    (selected == false ? removed : added).add(value);
    if (failure != null) return failure;
    final current = state.requireValue.selectors(type);
    state = AsyncData(
      _state(
        selected == false
            ? current.where((path) => path != value).toList()
            : [...current, value],
      ),
    );
    return null;
  }
}

Future<ProviderContainer> _container(
  _Core core, {
  List<AppData> installed = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      splitTunnelProvider.overrideWith(() => core),
      appsDataProvider.overrideWith((ref) => Stream.value(installed)),
      splitTunnelingAppsProvider.overrideWith(_WindowsApps.new),
    ],
  );
  addTearDown(container.dispose);
  container.listen(splitTunnelingAppsProvider, (_, _) {});
  await container.read(appsDataProvider.future);
  await container.read(splitTunnelingAppsProvider.future);
  return container;
}

void main() {
  test('undiscovered saved executable can be removed', () async {
    const path = r'C:\Games\Game.exe';
    final core = _Core([path]);
    final container = await _container(core);
    final app = container.read(splitTunnelingAppsProvider).requireValue.single;
    expect(app.name, 'Game.exe');
    expect(app, isA<StoredSplitTunnelApp>());

    await container.read(splitTunnelingAppsProvider.notifier).toggleApp(app);
    expect(core.removed, [path]);
    expect(await container.read(splitTunnelingAppsProvider.future), isEmpty);
  });

  test('a saved executable is not added again in another case', () async {
    final core = _Core([r'c:\games\game.exe']);
    final container = await _container(core);
    final notifier = container.read(splitTunnelingAppsProvider.notifier);

    expect(await notifier.addExecutable(r'C:\Games\GAME.EXE'), isNull);
    expect(core.added, isEmpty);
  });

  test('a new executable is saved as selected', () async {
    final core = _Core([]);
    final container = await _container(core);
    final notifier = container.read(splitTunnelingAppsProvider.notifier);

    expect(await notifier.addExecutable(r'C:\Games\Game.exe'), isNull);
    expect(core.added, [r'C:\Games\Game.exe']);
    expect(
      (await container.read(splitTunnelingAppsProvider.future)).single.name,
      'Game.exe',
    );
  });

  test('failed additions leave saved selections unchanged', () async {
    final failure = Failure(error: 'offline', localizedErrorMessage: 'Offline');
    final core = _Core([r'C:\Games\existing.exe'])..failure = failure;
    final container = await _container(core);
    final notifier = container.read(splitTunnelingAppsProvider.notifier);

    expect(await notifier.addExecutable(r'C:\Games\new.exe'), same(failure));
    expect(
      container.read(splitTunnelingAppsProvider).requireValue,
      hasLength(1),
    );
  });

  test('invalid and Lantern paths never reach the core', () async {
    final core = _Core([]);
    final container = await _container(core);
    final notifier = container.read(splitTunnelingAppsProvider.notifier);

    for (final path in [
      r'\\server\game.exe',
      'game.exe',
      r'C:\Games\shortcut.lnk',
      r'C:\Lantern\lantern.exe',
    ]) {
      expect(await notifier.addExecutable(path), isA<Failure>());
    }
    expect(core.added, isEmpty);
  });
}
