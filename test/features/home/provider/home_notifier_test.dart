import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

const _user = UserResponseModel(
  legacyID: 1,
  legacyToken: 'token',
  emailConfirmed: true,
  success: true,
  legacyUserData: UserDataModel(userLevel: 'pro'),
);

class _FakeLanternService implements LanternService {
  final ready = Completer<void>();
  final waitStarted = Completer<void>();
  int waitForRadianceCalls = 0;
  int getUserDataCalls = 0;
  int fetchUserDataCalls = 0;
  Either<Failure, UserResponseModel> fetchUserDataResult = right(_user);

  @override
  Future<void> waitForRadiance() {
    waitForRadianceCalls += 1;
    waitStarted.complete();
    return ready.future;
  }

  @override
  Future<Either<Failure, UserResponseModel>> getUserData() async {
    getUserDataCalls += 1;
    return right(_user);
  }

  @override
  Future<Either<Failure, UserResponseModel>> fetchUserData() async {
    fetchUserDataCalls += 1;
    return fetchUserDataResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  test('returns and applies server-fetched user data', () async {
    const fetchedUser = UserResponseModel(
      legacyID: 2,
      legacyToken: 'new-token',
      emailConfirmed: true,
      success: true,
      legacyUserData: UserDataModel(
        email: 'registered@example.com',
        userLevel: 'pro',
        unpassRegistered: true,
      ),
    );
    final service = _FakeLanternService()
      ..fetchUserDataResult = right(fetchedUser);
    service.ready.complete();
    final container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        appSettingProvider.overrideWithValue(const AppSetting()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(homeProvider.future);

    final result = await container.read(homeProvider.notifier).fetchUserData();

    expect(service.fetchUserDataCalls, 1);
    expect(result.isRight(), isTrue);
    expect(container.read(homeProvider).value, fetchedUser);
  });

  test('returns refresh failure without replacing cached user data', () async {
    final failure = Failure(
      error: 'network unavailable',
      localizedErrorMessage: 'Unable to refresh',
    );
    final service = _FakeLanternService()..fetchUserDataResult = left(failure);
    service.ready.complete();
    final container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        appSettingProvider.overrideWithValue(const AppSetting()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(homeProvider.future);

    final result = await container.read(homeProvider.notifier).fetchUserData();

    expect(result.isLeft(), isTrue);
    expect(container.read(homeProvider).value, _user);
  });
}
