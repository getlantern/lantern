import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/server_selection.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

class _FakeLanternService implements LanternService {
  @override
  Future<void> updateWidgetLocation({
    required String city,
    required String country,
    required String countryCode,
    required String displayName,
    required String serverName,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStorage extends LocalStorageService {
  final values = <String, String>{};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

class _FakeVpn extends VpnNotifier {
  final connection = Completer<Either<Failure, String>>();

  @override
  VPNStatus build() => VPNStatus.disconnected;

  @override
  Future<Either<Failure, String>> connectToServer(
    ServerLocationType location,
    String tag, {
    bool skipConflictCheck = false,
  }) {
    state = VPNStatus.connecting;
    return connection.future;
  }

  void set(VPNStatus status) => state = status;
}

class _PrivateServers extends AvailableServersNotifier {
  @override
  Future<AvailableServers> build() async => AvailableServers([
    Server(
      tag: 'private',
      type: 'samizdat',
      isLantern: false,
      location: GeoLocation(
        city: 'Amsterdam',
        country: 'Netherlands',
        countryCode: 'NL',
        latitude: 0,
        longitude: 0,
      ),
    ),
  ]);
}

ServerLocation _location(String tag) => ServerLocation(
  serverType: ServerLocationType.lanternLocation.name,
  serverName: tag,
  displayName: tag,
  protocol: '',
  city: tag,
);

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _FakeStorage storage;

  setUp(() async {
    await sl.reset();
    storage = _FakeStorage();
    sl.registerSingleton<LocalStorageService>(storage);
    container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(_FakeLanternService()),
        vpnProvider.overrideWith(_FakeVpn.new),
        availableServersProvider.overrideWith(_PrivateServers.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(sl.reset);
    // Build while disconnected so the startup refresh skips the stubbed service.
    container.read(serverLocationProvider);
  });

  ServerLocationNotifier notifier() =>
      container.read(serverLocationProvider.notifier);
  _FakeVpn vpn() => container.read(vpnProvider.notifier) as _FakeVpn;

  Future<bool> saveOnceConnected(FutureOr<void> Function() save) => notifier()
      .saveOnceConnected(save, attempt: notifier().beginSelectionAttempt());

  group('selection attempts', () {
    test(
      'does not save before an already-connected request is accepted',
      () async {
        vpn().set(VPNStatus.connected);
        final attempt = notifier().beginSelectionAttempt();
        await _pump();
        expect(notifier().isCurrentSelectionAttempt(attempt), isTrue);
        expect(storage.getServerLocation(), isNull);

        notifier().cancelSelectionAttempt(attempt);
        expect(
          await notifier().saveOnceConnected(
            () => notifier().updateServerLocation(_location('failed')),
            attempt: attempt,
          ),
          isFalse,
        );
        expect(storage.getServerLocation(), isNull);
      },
    );

    test(
      'stale completion and cancellation leave a newer save intact',
      () async {
        final first = notifier().beginSelectionAttempt();
        final second = notifier().beginSelectionAttempt();
        final saved = notifier().saveOnceConnected(
          () => notifier().updateServerLocation(_location('newer')),
          attempt: second,
        );

        notifier().cancelSelectionAttempt(first);
        expect(
          await notifier().saveOnceConnected(
            () => notifier().updateServerLocation(_location('stale')),
            attempt: first,
          ),
          isFalse,
        );
        vpn().set(VPNStatus.connected);
        expect(await saved, isTrue);
        expect(storage.getServerLocation()?.serverName, 'newer');
      },
    );
  });

  group('saveOnceConnected', () {
    test('saves immediately when already connected', () async {
      vpn().set(VPNStatus.connected);
      final saved = await saveOnceConnected(
        () => notifier().updateServerLocation(_location('a')),
      );

      expect(saved, isTrue);
      expect(container.read(serverLocationProvider).serverName, 'a');
    });

    test('defers the save until the VPN reports connected', () async {
      final result = saveOnceConnected(
        () => notifier().updateServerLocation(_location('a')),
      );
      await _pump();
      expect(container.read(serverLocationProvider).serverName, isNot('a'));

      vpn().set(VPNStatus.connecting);
      await _pump();
      expect(container.read(serverLocationProvider).serverName, isNot('a'));

      vpn().set(VPNStatus.connected);
      expect(await result, isTrue);
      expect(container.read(serverLocationProvider).serverName, 'a');
      expect(storage.getServerLocation()?.serverName, 'a');
    });

    test('drops the pending save when the VPN errors', () async {
      final result = saveOnceConnected(
        () => notifier().updateServerLocation(_location('a')),
      );
      vpn().set(VPNStatus.error);
      expect(await result, isFalse);

      // A later connection must not resurrect the failed request.
      vpn().set(VPNStatus.connected);
      await _pump();
      expect(container.read(serverLocationProvider).serverName, isNot('a'));
    });

    test('a disconnected attempt cannot save on a later connection', () async {
      final result = saveOnceConnected(
        () => notifier().updateServerLocation(_location('cancelled')),
      );
      vpn().set(VPNStatus.connecting);
      await _pump();
      vpn().set(VPNStatus.disconnected);
      await _pump();
      vpn().set(VPNStatus.connected);
      await _pump();

      expect(await result, isFalse);
      expect(
        container.read(serverLocationProvider).serverName,
        isNot('cancelled'),
      );
      expect(storage.getServerLocation()?.serverName, isNot('cancelled'));
    });

    test('a newer request retires the pending one', () async {
      final first = saveOnceConnected(
        () => notifier().updateServerLocation(_location('a')),
      );
      final second = saveOnceConnected(
        () => notifier().updateServerLocation(_location('b')),
      );
      expect(await first, isFalse);

      vpn().set(VPNStatus.connected);
      expect(await second, isTrue);
      expect(container.read(serverLocationProvider).serverName, 'b');
    });

    test('still resolves when the save itself throws', () async {
      vpn().set(VPNStatus.connected);
      final saved = await saveOnceConnected(
        () => throw StateError('disk full'),
      );
      expect(saved, isTrue);
    });
  });

  for (final cancelledStatus in [
    null,
    VPNStatus.disconnected,
    VPNStatus.error,
  ]) {
    for (final requestFinished in [false, true]) {
      testWidgets(
        'a private selection ${cancelledStatus == null ? 'survives disposal' : 'is cancelled by ${cancelledStatus.name}'} ${requestFinished ? 'after' : 'before'} request acceptance',
        (tester) async {
          notifier().updateServerLocation(_location('previous'));
          final subscription = container.listen(
            serverLocationProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);
          final showingSelection = ValueNotifier(true);
          addTearDown(showingSelection.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: ScreenUtilInit(
                designSize: const Size(393, 852),
                child: GlobalLoaderOverlay(
                  child: MaterialApp(
                    theme: AppTheme.appTheme(),
                    home: Scaffold(
                      body: ValueListenableBuilder(
                        valueListenable: showingSelection,
                        builder: (_, showing, _) => showing
                            ? const PrivateServerLocationListView()
                            : const SizedBox(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.tap(
            find.byKey(const Key('server_selection.private_server.private')),
          );
          await tester.pump();
          expect(container.read(vpnProvider), VPNStatus.connecting);
          if (requestFinished) {
            vpn().connection.complete(const Right('ok'));
            await tester.runAsync(_pump);
            await tester.pump();
          }
          showingSelection.value = false;
          await tester.pump();
          expect(find.byType(PrivateServerLocationListView), findsNothing);
          if (cancelledStatus != null) {
            vpn().set(cancelledStatus);
            await tester.runAsync(_pump);
            await tester.pump();
          }
          if (!requestFinished) {
            vpn().connection.complete(const Right('ok'));
            await tester.runAsync(_pump);
            await tester.pump();
          }
          vpn().set(VPNStatus.connected);
          await tester.runAsync(_pump);
          await tester.pump();

          final expected = cancelledStatus == null ? 'private' : 'previous';
          expect(container.read(serverLocationProvider).serverName, expected);
          expect(storage.getServerLocation()?.serverName, expected);
          expect(
            storage.getServerLocation()?.serverType,
            cancelledStatus == null
                ? ServerLocationType.privateServer.name
                : ServerLocationType.lanternLocation.name,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
