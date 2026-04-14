import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/router/router.gr.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

import '../utils/widget_wait_utils.dart';

const _existingUserEmail = 'smoke-existing@getlantern.org';
const _existingUserPassword = 'ExistingPass123!';
const _newUserEmail = 'smoke-signup@getlantern.org';
const _newUserPassword = 'NewPass123!';
const _deleteUserEmail = 'smoke-delete@getlantern.org';
const _deleteUserPassword = 'DeletePass123!';
const _recoveryCode = '123456';
const _invalidCredentialsMessage = 'Invalid email or password';

class _AuthSmokeScenarioContext {
  final ProviderContainer container;
  final AppRouter router;
  final _AuthSmokeFakeLanternService fakeService;

  _AuthSmokeScenarioContext({
    required this.container,
    required this.router,
    required this.fakeService,
  });

  void dispose() {
    container.dispose();
  }
}

class _InMemoryAppSettingNotifier extends AppSettingNotifier {
  _InMemoryAppSettingNotifier(this._initial);

  final AppSetting _initial;

  @override
  AppSetting build() => _initial;

  @override
  Future<void> update(AppSetting updated) async {
    state = updated;
  }
}

class _InMemoryHomeNotifier extends HomeNotifier {
  _InMemoryHomeNotifier(this._initialUser);

  final UserResponse _initialUser;

  @override
  Future<UserResponse> build() async => _initialUser;

  @override
  void updateUserData(UserResponse userData) {
    state = AsyncValue.data(userData);
  }

  @override
  void clearLogoutData() {
    ref.read(appSettingProvider.notifier).clearAuthSessionData();
    state = AsyncValue.data(UserResponse());
  }
}

class _AuthSmokeFakeLanternService implements LanternService {
  _AuthSmokeFakeLanternService({required this.loginUsers});

  final Map<String, String> loginUsers;
  final Map<String, UserResponse> _users = {};
  final Map<String, String> _recoveryCodes = {};
  bool forceLoginFailure = false;
  int deleteAccountCalls = 0;

  void seedUser({
    required String email,
    required String password,
    required UserResponse user,
  }) {
    loginUsers[email] = password;
    _users[email] = user;
  }

  @override
  Future<Either<Failure, UserResponse>> login({
    required String email,
    required String password,
  }) async {
    if (forceLoginFailure || loginUsers[email] != password) {
      return left(
        Failure(
          error: 'login_failed',
          localizedErrorMessage: _invalidCredentialsMessage,
        ),
      );
    }

    final user = _users[email] ?? _buildFreeUser(email: email);
    return right(user);
  }

  @override
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  }) async {
    if (loginUsers.containsKey(email)) {
      return left(
        Failure(
          error: 'signup_user_exists',
          localizedErrorMessage: 'signup_error_user_exists',
        ),
      );
    }
    seedUser(
      email: email,
      password: password,
      user: _buildFreeUser(email: email),
    );
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email) async {
    if (!loginUsers.containsKey(email)) {
      return left(
        Failure(error: 'unknown_email', localizedErrorMessage: 'unknown_email'),
      );
    }
    _recoveryCodes[email] = _recoveryCode;
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> validateRecoveryCode({
    required String email,
    required String code,
  }) async {
    if (_recoveryCodes[email] != code) {
      return left(
        Failure(
          error: 'invalid_code',
          localizedErrorMessage: 'Invalid recovery code',
        ),
      );
    }
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> completeRecoveryByEmail({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (_recoveryCodes[email] != code) {
      return left(
        Failure(
          error: 'invalid_code',
          localizedErrorMessage: 'Invalid recovery code',
        ),
      );
    }
    loginUsers[email] = newPassword;
    _users[email] = _users[email] ?? _buildFreeUser(email: email);
    return right(unit);
  }

  @override
  Future<Either<Failure, UserResponse>> logout(String email) async {
    return right(UserResponse()..success = true);
  }

  @override
  Future<Either<Failure, UserResponse>> deleteAccount({
    required String email,
    required String password,
    bool isSSO = false,
  }) async {
    deleteAccountCalls += 1;
    if (!isSSO && loginUsers[email] != password) {
      return left(
        Failure(
          error: 'invalid_credentials',
          localizedErrorMessage: _invalidCredentialsMessage,
        ),
      );
    }
    loginUsers.remove(email);
    _users.remove(email);
    _recoveryCodes.remove(email);
    return right(UserResponse()..success = true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserResponse _buildFreeUser({required String email}) {
  final userData = UserResponse_UserData()
    ..email = email
    ..userLevel = 'free';

  return UserResponse()
    ..success = true
    ..id = email
    ..legacyUserData = userData;
}

Future<_AuthSmokeScenarioContext> _startScenario(
  WidgetTester tester, {
  required AppSetting initialAppSetting,
  required UserResponse initialUser,
  required _AuthSmokeFakeLanternService fakeService,
}) async {
  await sl.reset();
  final router = AppRouter();
  sl.registerLazySingleton<AppRouter>(() => router);

  final container = ProviderContainer(
    overrides: [
      lanternServiceProvider.overrideWithValue(fakeService),
      appSettingProvider.overrideWith(
        () => _InMemoryAppSettingNotifier(initialAppSetting),
      ),
      homeProvider.overrideWith(() => _InMemoryHomeNotifier(initialUser)),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router.config()),
    ),
  );
  await tester.pumpAndSettle();

  return _AuthSmokeScenarioContext(
    container: container,
    router: router,
    fakeService: fakeService,
  );
}

Future<void> _showRoutes(
  WidgetTester tester,
  AppRouter router,
  List<PageRouteInfo> routes,
) async {
  router.replaceAll(routes);
  await tester.pumpAndSettle();
}

Future<void> _enterTextByKey(
  WidgetTester tester, {
  required Key key,
  required String value,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final finder = find.byKey(key);
  await WidgetWaitUtils.waitForFinder(
    tester,
    finder,
    timeout: timeout,
    reason: 'Expected field not visible: $key',
  );
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<void> _tapByKey(
  WidgetTester tester, {
  required Key key,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final finder = find.byKey(key);
  await WidgetWaitUtils.waitForFinder(
    tester,
    finder,
    timeout: timeout,
    reason: 'Expected button not visible: $key',
  );
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _runSignInSuccessScenario(WidgetTester tester) async {
  final fakeService = _AuthSmokeFakeLanternService(loginUsers: {})
    ..seedUser(
      email: _existingUserEmail,
      password: _existingUserPassword,
      user: _buildFreeUser(email: _existingUserEmail),
    );

  final context = await _startScenario(
    tester,
    initialAppSetting: const AppSetting(),
    initialUser: UserResponse(),
    fakeService: fakeService,
  );
  try {
    await _showRoutes(tester, context.router, const [Account(), SignInEmail()]);

    await _enterTextByKey(
      tester,
      key: AuthKeys.signInEmailField,
      value: _existingUserEmail,
    );
    await _tapByKey(tester, key: AuthKeys.signInEmailContinueButton);

    await _enterTextByKey(
      tester,
      key: AuthKeys.signInPasswordField,
      value: _existingUserPassword,
    );
    await _tapByKey(tester, key: AuthKeys.signInPasswordContinueButton);

    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.accountLogoutActionButton),
      timeout: const Duration(seconds: 10),
      reason: 'Logout action not visible after successful sign-in',
    );

    final settings = context.container.read(appSettingProvider);
    expect(settings.userLoggedIn, isTrue);
    expect(settings.email, _existingUserEmail);
    expect(settings.oAuthLoginProvider, SignUpMethodType.email.name);
    expect(settings.oAuthToken, isEmpty);
  } finally {
    context.dispose();
  }
}

Future<void> _runSignInFailureScenario(WidgetTester tester) async {
  final fakeService = _AuthSmokeFakeLanternService(loginUsers: {})
    ..seedUser(
      email: _existingUserEmail,
      password: _existingUserPassword,
      user: _buildFreeUser(email: _existingUserEmail),
    )
    ..forceLoginFailure = true;

  final context = await _startScenario(
    tester,
    initialAppSetting: const AppSetting(),
    initialUser: UserResponse(),
    fakeService: fakeService,
  );
  try {
    await _showRoutes(tester, context.router, const [SignInEmail()]);

    await _enterTextByKey(
      tester,
      key: AuthKeys.signInEmailField,
      value: _existingUserEmail,
    );
    await _tapByKey(tester, key: AuthKeys.signInEmailContinueButton);

    await _enterTextByKey(
      tester,
      key: AuthKeys.signInPasswordField,
      value: 'WrongPass123!',
    );
    await _tapByKey(tester, key: AuthKeys.signInPasswordContinueButton);

    await WidgetWaitUtils.waitForFinder(
      tester,
      find.text(_invalidCredentialsMessage),
      timeout: const Duration(seconds: 10),
      reason: 'Expected sign-in error dialog was not shown',
    );

    final settings = context.container.read(appSettingProvider);
    expect(settings.userLoggedIn, isFalse);
    expect(settings.email, isEmpty);
    expect(settings.oAuthToken, isEmpty);
    expect(settings.oAuthLoginProvider, isEmpty);
  } finally {
    context.dispose();
  }
}

Future<void> _runSignUpSuccessScenario(WidgetTester tester) async {
  final fakeService = _AuthSmokeFakeLanternService(loginUsers: {});

  final context = await _startScenario(
    tester,
    initialAppSetting: const AppSetting(),
    initialUser: UserResponse(),
    fakeService: fakeService,
  );
  try {
    await _showRoutes(tester, context.router, [
      AddEmail(authFlow: AuthFlow.signUp),
    ]);

    await _enterTextByKey(
      tester,
      key: AuthKeys.signUpEmailField,
      value: _newUserEmail,
    );
    await _tapByKey(tester, key: AuthKeys.signUpContinueButton);

    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(AuthKeys.confirmEmailCodeField),
      timeout: const Duration(seconds: 15),
      reason: 'Confirm email screen did not appear',
    );

    final pinEditable = find.descendant(
      of: find.byKey(AuthKeys.confirmEmailCodeField),
      matching: find.byType(EditableText),
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      pinEditable,
      timeout: const Duration(seconds: 10),
      reason: 'PIN input was not available',
    );
    await tester.enterText(pinEditable.first, _recoveryCode);
    await tester.pumpAndSettle();

    if (find.byKey(AuthKeys.confirmEmailContinueButton).evaluate().isNotEmpty) {
      await _tapByKey(tester, key: AuthKeys.confirmEmailContinueButton);
    }

    await _enterTextByKey(
      tester,
      key: AuthKeys.createPasswordField,
      value: _newUserPassword,
      timeout: const Duration(seconds: 15),
    );
    await _tapByKey(tester, key: AuthKeys.createPasswordContinueButton);

    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byType(AlertDialog),
      timeout: const Duration(seconds: 10),
      reason: 'Expected post-signup dialog was not shown',
    );

    final settings = context.container.read(appSettingProvider);
    expect(settings.userLoggedIn, isTrue);
    expect(settings.email, _newUserEmail);
    expect(settings.oAuthLoginProvider, SignUpMethodType.email.name);
    expect(settings.oAuthToken, isEmpty);
  } finally {
    context.dispose();
  }
}

Future<void> _runLogoutClearsSessionScenario(WidgetTester tester) async {
  final fakeService = _AuthSmokeFakeLanternService(loginUsers: {})
    ..seedUser(
      email: _existingUserEmail,
      password: _existingUserPassword,
      user: _buildFreeUser(email: _existingUserEmail),
    );

  final context = await _startScenario(
    tester,
    initialAppSetting: const AppSetting(
      userLoggedIn: true,
      email: _existingUserEmail,
      oAuthToken: 'session-token',
      oAuthLoginProvider: 'email',
    ),
    initialUser: _buildFreeUser(email: _existingUserEmail),
    fakeService: fakeService,
  );
  try {
    await _showRoutes(tester, context.router, const [Account()]);

    await _tapByKey(tester, key: AuthKeys.accountLogoutActionButton);
    await _tapByKey(tester, key: AuthKeys.accountLogoutConfirmButton);

    await WidgetWaitUtils.waitForFinderToDisappear(
      tester,
      find.byKey(AuthKeys.accountLogoutActionButton),
      timeout: const Duration(seconds: 10),
      reason: 'Logout action still visible after logout success',
    );

    final settings = context.container.read(appSettingProvider);
    expect(settings.userLoggedIn, isFalse);
    expect(settings.email, isEmpty);
    expect(settings.oAuthToken, isEmpty);
    expect(settings.oAuthLoginProvider, isEmpty);
  } finally {
    context.dispose();
  }
}

Future<void> _runDeleteAccountClearsSessionScenario(WidgetTester tester) async {
  final fakeService = _AuthSmokeFakeLanternService(loginUsers: {})
    ..seedUser(
      email: _deleteUserEmail,
      password: _deleteUserPassword,
      user: _buildFreeUser(email: _deleteUserEmail),
    );

  final context = await _startScenario(
    tester,
    initialAppSetting: const AppSetting(
      userLoggedIn: true,
      email: _deleteUserEmail,
      oAuthToken: '',
      oAuthLoginProvider: 'email',
    ),
    initialUser: _buildFreeUser(email: _deleteUserEmail),
    fakeService: fakeService,
  );
  try {
    await _showRoutes(tester, context.router, const [Account()]);

    await _tapByKey(tester, key: AuthKeys.accountDeleteActionButton);
    await _enterTextByKey(
      tester,
      key: AuthKeys.deleteAccountPasswordField,
      value: _deleteUserPassword,
      timeout: const Duration(seconds: 10),
    );
    await _tapByKey(tester, key: AuthKeys.deleteAccountConfirmButton);

    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byType(AlertDialog),
      timeout: const Duration(seconds: 10),
      reason: 'Delete-account success dialog did not appear',
    );

    final settings = context.container.read(appSettingProvider);
    expect(settings.userLoggedIn, isFalse);
    expect(settings.email, isEmpty);
    expect(settings.oAuthToken, isEmpty);
    expect(settings.oAuthLoginProvider, isEmpty);

    expect(context.fakeService.deleteAccountCalls, 1);
  } finally {
    context.dispose();
  }
}

Future<void> runAuthSignInSuccessSmoke(WidgetTester tester) =>
    _runSignInSuccessScenario(tester);

Future<void> runAuthSignInFailureSmoke(WidgetTester tester) =>
    _runSignInFailureScenario(tester);

Future<void> runAuthSignUpSuccessSmoke(WidgetTester tester) =>
    _runSignUpSuccessScenario(tester);

Future<void> runAuthLogoutClearsSessionSmoke(WidgetTester tester) =>
    _runLogoutClearsSessionScenario(tester);

Future<void> runAuthDeleteAccountClearsSessionSmoke(WidgetTester tester) =>
    _runDeleteAccountClearsSessionScenario(tester);
