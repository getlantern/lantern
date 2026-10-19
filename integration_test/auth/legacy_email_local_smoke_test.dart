import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/main.dart' as app;

import '../utils/app_robot.dart';
import '../utils/auth_robot.dart';
import '../utils/widget_wait_utils.dart';

const _fixtureDir = String.fromEnvironment('LEGACY_EMAIL_FIXTURE_DIR');
const _phase = String.fromEnvironment('LEGACY_EMAIL_PHASE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('legacy email binding: $_phase', (tester) async {
    expect(
      Platform.isLinux,
      isTrue,
      reason: 'This smoke uses the Linux daemon',
    );
    expect(_fixtureDir, isNotEmpty);
    expect(_phase, anyOf('bind', 'verify'));
    final fixture = await _readJson('ready.json');
    final api = Uri.parse(fixture['apiUrl'] as String);
    expect(api.scheme, 'http');
    expect(api.host, '127.0.0.1');
    expect(api.path, isEmpty);
    expect(fixture['proUrl'], '${api.origin}/v0/pro-server');
    expect(Platform.environment['LANTERN_E2E_API_URL'], api.origin);

    final email = fixture['targetEmail'] as String;
    final password = fixture['password'] as String;
    await app.main();
    final shell = AppRobot(tester);
    final auth = AuthRobot(tester, shell);
    try {
      await shell.waitForHomeReady();

      if (_phase == 'bind') {
        final placeholder = fixture['email'] as String;
        _expectAccount(await _readUser(auth), fixture, placeholder);
        _expectAccount(
          await _readUser(auth, refresh: true),
          fixture,
          placeholder,
        );
        expect(auth.isPro, isTrue);

        await shell.openSettings();
        await shell.tap(
          find.byKey(const Key('setting.account_tile')),
          name: 'Settings account tile',
        );
        await shell.tap(find.text('add_email'.i18n), name: 'Add email');
        await auth.submitSignUpEmail(email);
        await WidgetWaitUtils.waitForFinder(
          tester,
          find.byKey(AuthKeys.createPasswordField),
          timeout: const Duration(seconds: 15),
          reason: 'Binding did not ask for a new password',
        );
        await tester.enterText(
          find.byKey(AuthKeys.createPasswordField),
          password,
        );
        await shell.hideKeyboard();
        await shell.tap(
          find.byKey(AuthKeys.createPasswordContinueButton),
          name: 'Create password continue button',
          settle: false,
        );
        await auth.waitForConfirmEmailScreen(email: email);

        final otp = await _readJson('otp.json');
        expect(otp['email'], email);
        final code = otp['code'] as String;
        expect(code, matches(RegExp(r'^\d{6}$')));
        final wrongCode = code == '000000' ? '111111' : '000000';
        await auth.enterOtp(wrongCode);
        await auth.expectInvalidOtpErrorAndClear();
        _expectAccount(await _readUser(auth), fixture, placeholder);
        _expectAccount(
          await _readUser(auth, refresh: true),
          fixture,
          placeholder,
        );

        await auth.enterOtp(code);
        await WidgetWaitUtils.waitForFinder(
          tester,
          find.text('email_updated'.i18n),
          timeout: const Duration(seconds: 30),
          reason: 'Binding did not complete',
        );
        await shell.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('ok'.i18n),
          ),
          name: 'Email updated confirmation',
        );
        await shell.resetToRoot();
        expect(auth.isSignedIn, isTrue);
        await _expectBoundAccount(auth, fixture);
        await File('$_fixtureDir/bound').writeAsString('ok\n', flush: true);
      } else {
        expect(await File('$_fixtureDir/bound').exists(), isTrue);
        // This invocation starts after CI restarts both the app and daemon.
        await _expectBoundAccount(auth, fixture);
        expect(auth.isSignedIn, isTrue);
        await auth.logoutViaUi();
        expect(auth.isSignedIn, isFalse);
        await auth.signIn(email: email, password: password);
        await _expectBoundAccount(auth, fixture);
        await File('$_fixtureDir/done').writeAsString('ok\n', flush: true);
      }
    } catch (_) {
      await shell.captureScreenshot('legacy-email-$_phase-failure');
      rethrow;
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<Map<String, dynamic>> _readJson(String name) async =>
    jsonDecode(await File('$_fixtureDir/$name').readAsString())
        as Map<String, dynamic>;

Future<UserResponseModel> _readUser(
  AuthRobot auth, {
  bool refresh = false,
}) async {
  final service = auth.container.read(lanternServiceProvider);
  final result = refresh
      ? await service.fetchUserData()
      : await service.getUserData();
  return result.fold(
    (failure) => fail('Reading native account failed: ${failure.error}'),
    (user) => user,
  );
}

Future<void> _expectBoundAccount(
  AuthRobot auth,
  Map<String, dynamic> fixture,
) async {
  final email = fixture['targetEmail'] as String;
  _expectAccount(await _readUser(auth), fixture, email);
  _expectAccount(await _readUser(auth, refresh: true), fixture, email);
  _expectAccount(await _readUser(auth), fixture, email);
  await auth.container.read(homeProvider.notifier).refreshUser();
  _expectAccount(
    auth.container.read(homeProvider).requireValue,
    fixture,
    email,
  );
  expect(auth.signedInEmail, email);
  expect(auth.isPro, isTrue);
}

void _expectAccount(
  UserResponseModel user,
  Map<String, dynamic> fixture,
  String email,
) {
  final data = user.legacyUserData;
  expect(user.legacyID, fixture['userId']);
  expect(user.legacyToken == fixture['proToken'], isTrue);
  expect(data.userId, fixture['userId']);
  expect(data.email, email);
  expect(data.isPro, isTrue);
  expect(data.expiration, fixture['expiration']);
  expect(data.subscriptionData.subscriptionID, fixture['subscriptionId']);
  expect(
    data.devices.map((device) => device.deviceId),
    unorderedEquals(
      (fixture['devices'] as List).map((device) => device['id'] as String),
    ),
  );
  expect(
    data.devices.map((device) => device.deviceId),
    contains(fixture['deviceId']),
  );
  if (email == fixture['targetEmail']) {
    expect(user.emailConfirmed, isTrue);
    expect(user.hasLegacyPlaceholderEmail, isFalse);
  } else {
    expect(user.hasLegacyPlaceholderEmail, isTrue);
  }
}
