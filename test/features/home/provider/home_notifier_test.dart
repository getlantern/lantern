import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

const _user = UserResponseModel(
  legacyID: 1,
  legacyToken: 'token',
  emailConfirmed: true,
  success: true,
  legacyUserData: UserDataModel(userLevel: 'pro'),
);

UserResponseModel _userWith({
  required String userLevel,
  String email = '',
  bool deviceLinked = false,
}) => UserResponseModel(
  legacyID: 1,
  legacyToken: 'token',
  emailConfirmed: email.isNotEmpty,
  success: true,
  legacyUserData: UserDataModel(
    userLevel: userLevel,
    email: email,
    deviceID: 'device-1',
    devices: deviceLinked
        ? const [DeviceModel(deviceId: 'device-1', name: 'phone', created: 0)]
        : const [],
  ),
);

class _FakeLanternService implements LanternService {
  final ready = Completer<void>();
  final waitStarted = Completer<void>();
  int waitForRadianceCalls = 0;
  int getUserDataCalls = 0;
  Future<Either<Failure, UserResponseModel>> Function() readUser = () async =>
      right(_user);

  @override
  Future<void> waitForRadiance() {
    waitForRadianceCalls += 1;
    waitStarted.complete();
    return ready.future;
  }

  @override
  Future<Either<Failure, UserResponseModel>> getUserData() async {
    getUserDataCalls += 1;
    return readUser();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory settings so login-state changes are observable without storage.
class _FakeAppSettings extends AppSettingNotifier {
  _FakeAppSettings(this.initial);

  final AppSetting initial;

  @override
  AppSetting build() => initial;

  @override
  Future<void> update(AppSetting updated) async {
    state = updated;
  }
}

/// Loads [user] with the app's stored login flag set to [loggedIn] and returns
/// the login flag after the device check has run.
Future<bool> _loggedInAfterLoad(
  UserResponseModel user, {
  required bool loggedIn,
}) async {
  final service = _FakeLanternService()
    ..readUser = (() async => right(user))
    ..ready.complete();
  final container = ProviderContainer(
    overrides: [
      lanternServiceProvider.overrideWithValue(service),
      serverLocationProvider.overrideWithValue(initialServerLocation()),
      appSettingProvider.overrideWith(
        () => _FakeAppSettings(AppSetting(userLoggedIn: loggedIn)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(homeProvider.future);
  return container.read(appSettingProvider).userLoggedIn;
}

void main() {
  test('waits for Radiance before loading user data', () async {
    final service = _FakeLanternService();
    final container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        appSettingProvider.overrideWithValue(
          const AppSetting(userLoggedIn: true),
        ),
      ],
    );
    addTearDown(container.dispose);

    final user = container.read(homeProvider.future);
    await service.waitStarted.future;

    expect(service.waitForRadianceCalls, 1);
    expect(service.getUserDataCalls, 0);

    service.ready.complete();

    expect(await user, _user);
    expect(service.getUserDataCalls, 1);
  });

  test('reload waits for the initial account read to finish', () async {
    final service = _FakeLanternService();
    final container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        appSettingProvider.overrideWithValue(
          const AppSetting(userLoggedIn: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(homeProvider.notifier);
    final reload = notifier.reloadUserData();
    await service.waitStarted.future;
    expect(service.getUserDataCalls, 0);

    service.ready.complete();
    await reload;
    expect(service.getUserDataCalls, 2);
    expect(container.read(homeProvider).value, _user);
  });

  test('reload ignores a result after the provider is disposed', () async {
    final service = _FakeLanternService();
    final container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        appSettingProvider.overrideWithValue(
          const AppSetting(userLoggedIn: true),
        ),
      ],
    );
    service.ready.complete();
    await container.read(homeProvider.future);
    final readStarted = Completer<void>();
    final response = Completer<Either<Failure, UserResponseModel>>();
    service.readUser = () {
      readStarted.complete();
      return response.future;
    };
    final reload = container.read(homeProvider.notifier).reloadUserData();
    await readStarted.future;
    container.dispose();
    response.complete(right(_user));
    await reload;
  });

  group('stale logged-in state', () {
    test('clears the flag for a free account with no email', () async {
      final loggedIn = await _loggedInAfterLoad(
        _userWith(userLevel: 'free'),
        loggedIn: true,
      );
      expect(loggedIn, isFalse);
    });

    test('keeps a free account with an email logged in', () async {
      final loggedIn = await _loggedInAfterLoad(
        _userWith(userLevel: 'free', email: 'user@example.com'),
        loggedIn: true,
      );
      expect(loggedIn, isTrue);
    });

    test('keeps an expired account with an email logged in', () async {
      final loggedIn = await _loggedInAfterLoad(
        _userWith(userLevel: 'expired', email: 'user@example.com'),
        loggedIn: true,
      );
      expect(loggedIn, isTrue);
    });

    test('clears the flag for an expired account with no email', () async {
      final loggedIn = await _loggedInAfterLoad(
        _userWith(userLevel: 'expired', deviceLinked: true),
        loggedIn: true,
      );
      expect(loggedIn, isFalse);
    });

    test('still auto-logs in a Pro device with no email', () async {
      final loggedIn = await _loggedInAfterLoad(
        _userWith(userLevel: 'pro', deviceLinked: true),
        loggedIn: false,
      );
      expect(loggedIn, isTrue);
    });
  });
}
