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
}
