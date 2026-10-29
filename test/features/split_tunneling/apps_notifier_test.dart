import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/split_tunneling/provider/apps_data_provider.dart';
import 'package:lantern/features/split_tunneling/provider/apps_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _WindowsApps extends SplitTunnelingApps {
  @override
  SplitTunnelFilterType getFilterType() => SplitTunnelFilterType.processPath;
}

class _FakeService implements LanternService {
  List<String> paths = [];
  final added = <String>[];
  final removed = <String>[];
  String? normalizedPath;
  Failure? addFailure;
  Failure? readFailure;
  Completer<void>? addGate;
  Completer<Either<Failure, List<String>>>? nextRead;
  Completer<void>? blockedRead;

  @override
  Future<Either<Failure, List<String>>> getSplitTunnelItems(
    SplitTunnelFilterType type,
  ) async {
    expect(type, SplitTunnelFilterType.processPath);
    if (nextRead case final pending?) {
      nextRead = null;
      blockedRead?.complete();
      return pending.future;
    }
    return readFailure == null ? right([...paths]) : left(readFailure!);
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
    SplitTunnelFilterType type,
    String path,
  ) async {
    expect(type, SplitTunnelFilterType.processPath);
    added.add(path);
    if (addFailure != null) return left(addFailure!);
    if (addGate case final gate?) await gate.future;
    paths.add(normalizedPath ?? path);
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
    SplitTunnelFilterType type,
    String path,
  ) async {
    expect(type, SplitTunnelFilterType.processPath);
    removed.add(path);
    paths.remove(path);
    return right(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _container(
  _FakeService service, {
  List<AppData> installed = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      lanternServiceProvider.overrideWithValue(service),
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
  test('undiscovered saved executable can be reloaded and removed', () async {
    const path = r'C:\Games\Game.exe';
    final service = _FakeService()..paths = [path];
    final container = await _container(service);
    final app = container.read(splitTunnelingAppsProvider).requireValue.single;
    expect(app.name, 'Game.exe');
    expect(app.appPath, path);

    await container.read(splitTunnelingAppsProvider.notifier).toggleApp(app);
    expect(service.removed, [path]);
    expect(await container.read(splitTunnelingAppsProvider.future), isEmpty);
  });

  test('matching is case-insensitive and keeps stored removal path', () async {
    const saved = r'c:\games\game.exe';
    final service = _FakeService()..paths = [saved];
    final container = await _container(
      service,
      installed: [
        const AppData(
          name: 'Example Game',
          bundleId: '',
          appPath: r'C:\Games\Game.exe',
        ),
      ],
    );
    final app = container.read(splitTunnelingAppsProvider).requireValue.single;
    expect(app.name, 'Example Game');
    expect(app.appPath, saved);
    final notifier = container.read(splitTunnelingAppsProvider.notifier);
    expect(await notifier.addExecutable(r'C:\Games\GAME.EXE'), isNull);
    expect(service.added, isEmpty);
    expect(service.removed, isEmpty);
  });

  test('adding an executable reads back native normalized identity', () async {
    const short = r'C:\PROGRA~1\Game\Game.exe';
    const long = r'C:\Program Files\Game\Game.exe';
    final service = _FakeService()..normalizedPath = long;
    final container = await _container(service);
    final notifier = container.read(splitTunnelingAppsProvider.notifier);

    expect(await notifier.addExecutable(short), isNull);
    expect(service.added, [short]);
    expect(
      container.read(splitTunnelingAppsProvider).requireValue.single.appPath,
      long,
    );
    container.invalidate(splitTunnelingAppsProvider);
    expect(
      (await container.read(splitTunnelingAppsProvider.future)).single.appPath,
      long,
    );
  });

  test(
    'discovery refresh cannot overwrite a completed executable addition',
    () async {
      const path = r'C:\Games\Game.exe';
      final service = _FakeService();
      final installed = StreamController<List<AppData>>();
      addTearDown(installed.close);
      final container = ProviderContainer(
        overrides: [
          lanternServiceProvider.overrideWithValue(service),
          appsDataProvider.overrideWith((ref) => installed.stream),
          splitTunnelingAppsProvider.overrideWith(_WindowsApps.new),
        ],
      );
      addTearDown(container.dispose);
      container.listen(splitTunnelingAppsProvider, (_, _) {});
      await container.read(splitTunnelingAppsProvider.future);

      service.addGate = Completer<void>();
      final notifier = container.read(splitTunnelingAppsProvider.notifier);
      final addition = notifier.addExecutable(path);
      expect(service.added, [path]);

      final staleRead = Completer<Either<Failure, List<String>>>();
      service.nextRead = staleRead;
      service.blockedRead = Completer<void>();
      installed.add(const []);
      await service.blockedRead!.future;

      service.addGate!.complete();
      expect(await addition, isNull);
      expect(
        (await container.read(
          splitTunnelingAppsProvider.future,
        )).single.appPath,
        path,
      );

      staleRead.complete(right([]));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(splitTunnelingAppsProvider).requireValue.single.appPath,
        path,
      );
    },
  );

  test('failed additions leave saved selections unchanged', () async {
    final failure = Failure(error: 'offline', localizedErrorMessage: 'Offline');
    final service = _FakeService()
      ..paths = [r'C:\Games\existing.exe']
      ..addFailure = failure;
    final container = await _container(service);
    final notifier = container.read(splitTunnelingAppsProvider.notifier);

    expect(await notifier.addExecutable(r'C:\Games\new.exe'), same(failure));
    expect(
      container.read(splitTunnelingAppsProvider).requireValue,
      hasLength(1),
    );
  });

  test(
    'failed readback reports failure without inventing a saved identity',
    () async {
      final failure = Failure(
        error: 'offline',
        localizedErrorMessage: 'Offline',
      );
      final service = _FakeService()..paths = [r'C:\Games\existing.exe'];
      final container = await _container(service);
      service.readFailure = failure;
      final notifier = container.read(splitTunnelingAppsProvider.notifier);

      expect(await notifier.addExecutable(r'C:\Games\new.exe'), same(failure));
      expect(
        container.read(splitTunnelingAppsProvider).requireValue.single.appPath,
        r'C:\Games\existing.exe',
      );
    },
  );

  test('invalid and Lantern paths never reach the core', () async {
    final service = _FakeService();
    final container = await _container(service);
    final notifier = container.read(splitTunnelingAppsProvider.notifier);

    for (final path in [
      r'\\server\game.exe',
      'game.exe',
      r'C:\Games\shortcut.lnk',
      r'C:\Lantern\lantern.exe',
    ]) {
      expect(await notifier.addExecutable(path), isA<Failure>());
    }
    expect(service.added, isEmpty);
  });
}
