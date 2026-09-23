import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/notification_service.dart';
import 'package:lantern/core/services/rating_prompt_service.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _FakeLanternService implements LanternService {
  final statusController = StreamController<LanternStatus>.broadcast();

  Either<Failure, bool> isConnectedResult = right(false);
  Completer<Either<Failure, bool>>? isConnectedCompleter;
  Object? isConnectedException;
  int isVPNConnectedCalls = 0;
  int startVPNCalls = 0;
  int stopVPNCalls = 0;
  Either<Failure, String> stopResult = right('ok');
  Completer<Either<Failure, String>>? stopCompleter;
  Object? stopException;

  @override
  Future<Either<Failure, bool>> isVPNConnected() async {
    isVPNConnectedCalls += 1;
    if (isConnectedException != null) {
      throw isConnectedException!;
    }
    final completer = isConnectedCompleter;
    if (completer != null) {
      return completer.future;
    }
    return isConnectedResult;
  }

  @override
  Stream<LanternStatus> watchVPNStatus() => statusController.stream;

  @override
  Future<Either<Failure, String>> startVPN() async {
    startVPNCalls += 1;
    return right('ok');
  }

  @override
  Future<Either<Failure, String>> stopVPN() async {
    stopVPNCalls += 1;
    if (stopException != null) throw stopException!;
    final completer = stopCompleter;
    if (completer != null) return completer.future;
    return stopResult;
  }

  @override
  Future<bool> checkVpnConflict() async => false;

  @override
  Future<bool> isTagAvailable(String tag) async => true;

  Future<void> dispose() => statusController.close();

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

class _FakeAppSettings extends AppSettingNotifier {
  @override
  AppSetting build() => const AppSetting();

  @override
  void setSuccessfulConnection(bool value) {}
}

ProviderContainer _container(_FakeLanternService service) {
  return ProviderContainer(
    overrides: [
      lanternServiceProvider.overrideWithValue(service),
      serverLocationProvider.overrideWithValue(initialServerLocation()),
      appSettingProvider.overrideWith(_FakeAppSettings.new),
    ],
  );
}

void _disposeContainerAndService(
  ProviderContainer container,
  _FakeLanternService service,
) {
  addTearDown(() async {
    container.dispose();
    await service.dispose();
  });
}

Future<void> _pumpProviderQueue() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('VpnNotifier', () {
    test('hydrates initial connected state from core', () async {
      final service = _FakeLanternService()..isConnectedResult = right(true);
      final container = _container(service);
      _disposeContainerAndService(container, service);

      expect(container.read(vpnProvider), VPNStatus.disconnected);

      await _pumpProviderQueue();

      expect(service.isVPNConnectedCalls, 1);
      expect(container.read(vpnProvider), VPNStatus.connected);
    });

    test('stream status wins over slower initial hydration', () async {
      final service = _FakeLanternService()
        ..isConnectedCompleter = Completer<Either<Failure, bool>>();
      final container = _container(service);
      _disposeContainerAndService(container, service);
      final statusSub = container.listen<AsyncValue<LanternStatus>>(
        vPNStatusProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(statusSub.close);

      container.read(vpnProvider);
      await _pumpProviderQueue();
      service.statusController.add(
        LanternStatus(status: VPNStatus.disconnected),
      );
      await _pumpProviderQueue();

      expect(container.read(vpnProvider), VPNStatus.disconnected);

      service.isConnectedCompleter!.complete(right(true));
      await _pumpProviderQueue();

      expect(container.read(vpnProvider), VPNStatus.disconnected);
    });

    test('thrown hydration failures become VPNStatus.error', () async {
      final service = _FakeLanternService()
        ..isConnectedException = StateError('hydration failed');
      final container = _container(service);
      _disposeContainerAndService(container, service);

      expect(container.read(vpnProvider), VPNStatus.disconnected);

      await _pumpProviderQueue();

      expect(service.isVPNConnectedCalls, 1);
      expect(container.read(vpnProvider), VPNStatus.error);
    });

    test(
      'starts VPN from an error state because the switch displays off',
      () async {
        final service = _FakeLanternService();
        final container = _container(service);
        _disposeContainerAndService(container, service);
        final statusSub = container.listen<AsyncValue<LanternStatus>>(
          vPNStatusProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(statusSub.close);

        container.read(vpnProvider);
        await _pumpProviderQueue();
        service.statusController.add(
          LanternStatus(status: VPNStatus.error, error: 'connect failed'),
        );
        await _pumpProviderQueue();

        expect(container.read(vpnProvider), VPNStatus.error);

        final result = await container
            .read(vpnProvider.notifier)
            .onVPNStateChange();

        expect(result.isRight(), isTrue);
        expect(service.startVPNCalls, 1);
        expect(service.stopVPNCalls, 0);
      },
    );

    test(
      'status stream errors become VPNStatus.error instead of crashing',
      () async {
        final service = _FakeLanternService();
        final container = _container(service);
        _disposeContainerAndService(container, service);
        final statusSub = container.listen<AsyncValue<LanternStatus>>(
          vPNStatusProvider,
          (previous, next) {},
          fireImmediately: true,
        );
        addTearDown(statusSub.close);

        container.read(vpnProvider);
        await _pumpProviderQueue();
        service.statusController.addError(StateError('status stream failed'));
        await _pumpProviderQueue();

        expect(container.read(vpnProvider), VPNStatus.error);
        final status = container.read(vPNStatusProvider);
        expect(status.hasValue, isTrue);
        expect(status.value?.status, VPNStatus.error);
        expect(status.value?.error, contains('status stream failed'));

        service.statusController.add(
          LanternStatus(
            status: VPNStatus.disconnected,
            origin: VPNStatusOrigin.settingsMutation,
          ),
        );
        await _pumpProviderQueue();

        expect(container.read(vpnProvider), VPNStatus.disconnected);
        final recoveredStatus = container.read(vPNStatusProvider);
        expect(recoveredStatus.hasValue, isTrue);
        expect(recoveredStatus.value?.status, VPNStatus.disconnected);
      },
    );
  });

  group('rating session lifecycle', () {
    late _FakeLanternService service;
    late ProviderContainer container;
    late RatingPromptService rating;
    late DateTime now;

    setUp(() async {
      await sl.reset();
      now = DateTime.utc(2026, 9, 21);
      rating = RatingPromptService(
        _FakeStorage(),
        now: () => now,
        isStoreBuild: () => false,
      );
      sl.registerSingleton<RatingPromptService>(rating);
      sl.registerSingleton<NotificationService>(NotificationService());
      service = _FakeLanternService()..isConnectedResult = right(true);
      container = _container(service);
      container.listen(vpnProvider, (_, _) {});
      await _pumpProviderQueue();
      now = now.add(RatingPromptService.minSessionDuration);
    });

    tearDown(() async {
      container.dispose();
      await service.dispose();
      await sl.reset();
    });

    Future<void> emit(VPNStatus status) async {
      service.statusController.add(LanternStatus(status: status));
      await _pumpProviderQueue();
    }

    test(
      'counts once after confirmed disconnect, not command success',
      () async {
        final notifier = container.read(vpnProvider.notifier);
        await notifier.onVPNStateChange();
        expect(rating.sessions, 0);
        await notifier.onVPNStateChange();
        expect(service.stopVPNCalls, 1);
        await emit(VPNStatus.disconnected);
        expect(rating.sessions, 1);
        await emit(VPNStatus.disconnected);
        expect(rating.sessions, 1);
      },
    );

    test(
      'a failed stop preserves the session for a successful retry',
      () async {
        service.stopResult = left(
          Failure(error: 'stop failed', localizedErrorMessage: 'stop failed'),
        );
        final notifier = container.read(vpnProvider.notifier);
        expect((await notifier.onVPNStateChange()).isLeft(), isTrue);
        expect(rating.sessions, 0);
        service.stopResult = right('ok');
        await notifier.onVPNStateChange();
        await emit(VPNStatus.disconnected);
        expect(service.stopVPNCalls, 2);
        expect(rating.sessions, 1);
      },
    );

    test(
      'thrown stop failures release the guard and preserve the session',
      () async {
        service.stopException = StateError('stop failed');
        final notifier = container.read(vpnProvider.notifier);
        await expectLater(notifier.onVPNStateChange(), throwsStateError);
        service.stopException = null;
        await notifier.onVPNStateChange();
        await emit(VPNStatus.disconnected);
        expect(service.stopVPNCalls, 2);
        expect(rating.sessions, 1);
      },
    );

    test(
      'rapid taps send one stop and accept status before the reply',
      () async {
        service.stopCompleter = Completer<Either<Failure, String>>();
        final notifier = container.read(vpnProvider.notifier);
        final stop = notifier.onVPNStateChange();
        await notifier.onVPNStateChange();
        expect(service.stopVPNCalls, 1);
        expect(rating.sessions, 0);
        await emit(VPNStatus.disconnected);
        expect(rating.sessions, 1);
        await notifier.onVPNStateChange();
        expect(service.startVPNCalls, 0);
        service.stopCompleter!.complete(right('ok'));
        await stop;
        expect(rating.sessions, 1);
      },
    );

    test('explicit user stops outside the main switch count too', () async {
      await container.read(vpnProvider.notifier).stopVPN(userInitiated: true);
      await emit(VPNStatus.disconnected);
      expect(rating.sessions, 1);
    });

    test('concurrent stop callers share the native result', () async {
      service.stopCompleter = Completer<Either<Failure, String>>();
      final notifier = container.read(vpnProvider.notifier);
      final first = notifier.stopVPN(userInitiated: true);
      final second = notifier.stopVPN();
      expect(service.stopVPNCalls, 1);
      service.stopCompleter!.complete(
        left(
          Failure(error: 'stop failed', localizedErrorMessage: 'stop failed'),
        ),
      );
      expect((await first).isLeft(), isTrue);
      expect((await second).isLeft(), isTrue);
      expect(rating.sessions, 0);
    });

    test('programmatic and unexpected disconnects do not count', () async {
      await container.read(vpnProvider.notifier).stopVPN();
      await emit(VPNStatus.disconnected);
      expect(rating.sessions, 0);
      await emit(VPNStatus.connected);
      now = now.add(RatingPromptService.minSessionDuration);
      await emit(VPNStatus.disconnected);
      expect(rating.sessions, 0);
    });

    test('an error cancels pending user intent', () async {
      await container.read(vpnProvider.notifier).onVPNStateChange();
      await emit(VPNStatus.error);
      await emit(VPNStatus.disconnected);
      expect(rating.sessions, 0);
    });

    test('a stop that returns to connected can be retried', () async {
      final notifier = container.read(vpnProvider.notifier);
      await notifier.onVPNStateChange();
      await emit(VPNStatus.disconnecting);
      await emit(VPNStatus.connected);
      await notifier.onVPNStateChange();
      await emit(VPNStatus.disconnected);
      expect(service.stopVPNCalls, 2);
      expect(rating.sessions, 1);
    });

    test('a new connection does not inherit a pending disconnect', () async {
      await container.read(vpnProvider.notifier).onVPNStateChange();
      await emit(VPNStatus.connecting);
      await emit(VPNStatus.connected);
      await emit(VPNStatus.disconnected);
      expect(rating.sessions, 0);
    });

    test('startup while disconnected clears a persisted session', () async {
      container.dispose();
      now = now.add(const Duration(days: 1));
      service.isConnectedResult = right(false);
      container = _container(service);
      container.listen(vpnProvider, (_, _) {});
      await _pumpProviderQueue();
      expect(container.read(vpnProvider), VPNStatus.disconnected);

      await emit(VPNStatus.connected);
      now = now.add(
        RatingPromptService.minSessionDuration - const Duration(seconds: 1),
      );
      await container.read(vpnProvider.notifier).onVPNStateChange();
      await emit(VPNStatus.disconnected);
      expect(rating.sessions, 0);

      await emit(VPNStatus.connected);
      now = now.add(RatingPromptService.minSessionDuration);
      await container.read(vpnProvider.notifier).onVPNStateChange();
      await emit(VPNStatus.disconnected);
      expect(rating.sessions, 1);
    });
  });
}
