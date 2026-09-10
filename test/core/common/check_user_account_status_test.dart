import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

const _proUser = UserResponseModel(
  legacyID: 1,
  legacyToken: 'test-token',
  emailConfirmed: true,
  success: true,
  legacyUserData: UserDataModel(userLevel: 'pro', expiration: 200),
);

class _FakeLanternService implements LanternService {
  int fetchCalls = 0;
  Future<Either<Failure, UserResponseModel>> Function() fetch = () async =>
      right(_proUser);

  @override
  Future<void> waitForRadiance() async {}

  @override
  Future<Either<Failure, UserResponseModel>> getUserData() async =>
      right(_proUser);

  @override
  Future<Either<Failure, UserResponseModel>> fetchUserData() {
    fetchCalls++;
    return fetch();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeLanternService service;
  late BuildContext screenContext;
  late WidgetRef screenRef;

  Widget harness() => ProviderScope(
    overrides: [
      lanternServiceProvider.overrideWithValue(service),
      appSettingProvider.overrideWithValue(
        const AppSetting(userLoggedIn: true),
      ),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        screenContext = context;
        screenRef = ref;
        return const SizedBox();
      },
    ),
  );

  setUp(() => service = _FakeLanternService());

  testWidgets('stops before fetching when the screen closes during a delay', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    final result = checkUserAccountStatus(screenRef, screenContext);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));

    expect(await result, isFalse);
    expect(service.fetchCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores a fetch that finishes after the screen closes', (
    tester,
  ) async {
    final response = Completer<Either<Failure, UserResponseModel>>();
    service.fetch = () => response.future;
    await tester.pumpWidget(harness());
    final result = checkUserAccountStatus(
      screenRef,
      screenContext,
      delays: [Duration.zero],
    );
    expect(service.fetchCalls, 1);
    await tester.pumpWidget(const SizedBox());
    response.complete(right(_proUser));
    await tester.pump();

    expect(await result, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retries a transient failure and publishes confirmed user data', (
    tester,
  ) async {
    service.fetch = () async => service.fetchCalls == 1
        ? left(Failure(error: 'offline', localizedErrorMessage: 'offline'))
        : right(_proUser);
    await tester.pumpWidget(harness());
    await screenRef.read(homeProvider.future);
    final result = checkUserAccountStatus(
      screenRef,
      screenContext,
      expirationBefore: 100,
      delays: [const Duration(seconds: 1), const Duration(seconds: 2)],
    );
    await tester.pump(const Duration(seconds: 1));
    expect(service.fetchCalls, 1);
    await tester.pump(const Duration(seconds: 2));

    expect(await result, isTrue);
    expect(service.fetchCalls, 2);
    expect(screenRef.read(homeProvider).value, _proUser);
  });
}
