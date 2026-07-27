import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/auth/add_email.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

const _anonymousUser = UserResponseModel(
  legacyID: 1,
  legacyToken: 'anonymous-token',
  emailConfirmed: false,
  success: true,
  legacyUserData: UserDataModel(userLevel: 'pro'),
);

const _registeredUser = UserResponseModel(
  legacyID: 1,
  legacyToken: 'registered-token',
  emailConfirmed: true,
  success: true,
  legacyUserData: UserDataModel(
    email: 'backend@example.com',
    userLevel: 'pro',
    unpassRegistered: true,
  ),
);

final _refreshFailure = Failure(
  error: 'network unavailable',
  localizedErrorMessage: 'Unable to refresh account',
);

final _recoveryFailure = Failure(
  error: 'stop after recording recovery',
  localizedErrorMessage: 'Recovery stopped for test',
);

class _InMemoryAppSettingNotifier extends AppSettingNotifier {
  @override
  AppSetting build() => const AppSetting();

  @override
  Future<void> update(AppSetting updated) async {
    state = updated;
  }
}

class _FakeLanternService implements LanternService {
  _FakeLanternService({
    required this.cachedUser,
    required List<Either<Failure, UserResponseModel>> fetchResults,
  }) : _fetchResults = fetchResults;

  final UserResponseModel cachedUser;
  final List<Either<Failure, UserResponseModel>> _fetchResults;
  Either<Failure, Unit> signUpResult = right(unit);
  Either<Failure, UserResponseModel> logoutResult = right(_anonymousUser);
  int fetchCalls = 0;
  int signUpCalls = 0;
  int logoutCalls = 0;
  String? recoveryEmail;
  String? logoutEmail;

  @override
  Future<void> waitForRadiance() async {}

  @override
  Future<Either<Failure, UserResponseModel>> getUserData() async {
    return right(cachedUser);
  }

  @override
  Future<Either<Failure, UserResponseModel>> fetchUserData() async {
    fetchCalls += 1;
    if (_fetchResults.isEmpty) {
      return right(cachedUser);
    }
    return _fetchResults.removeAt(0);
  }

  @override
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  }) async {
    signUpCalls += 1;
    return signUpResult;
  }

  @override
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email) async {
    recoveryEmail = email;
    return left(_recoveryFailure);
  }

  @override
  Future<Either<Failure, UserResponseModel>> logout(String email) async {
    logoutCalls += 1;
    logoutEmail = email;
    return logoutResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _pumpAddEmail(
  WidgetTester tester,
  _FakeLanternService service,
) async {
  final container = ProviderContainer(
    overrides: [
      lanternServiceProvider.overrideWithValue(service),
      appSettingProvider.overrideWith(_InMemoryAppSettingNotifier.new),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        child: GlobalLoaderOverlay(
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: const AddEmail(authFlow: AuthFlow.signUp),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

TextFormField _emailField(WidgetTester tester) {
  return tester.widget<TextFormField>(find.byKey(AuthKeys.signUpEmailField));
}

Finder _continueButton() => find.descendant(
  of: find.byKey(AuthKeys.signUpContinueButton),
  matching: find.byType(ElevatedButton),
);

void main() {
  testWidgets(
    'refreshes on entry and routes a registered user with the backend email',
    (tester) async {
      final service = _FakeLanternService(
        cachedUser: _anonymousUser,
        fetchResults: [right(_registeredUser), right(_registeredUser)],
      );
      final container = await _pumpAddEmail(tester, service);
      addTearDown(container.dispose);

      expect(service.fetchCalls, 1);
      expect(_emailField(tester).controller!.text, 'backend@example.com');
      expect(_emailField(tester).enabled, isFalse);

      await tester.tap(_continueButton());
      await tester.pumpAndSettle();

      expect(service.fetchCalls, 2);
      expect(service.recoveryEmail, 'backend@example.com');
      expect(service.signUpCalls, 0);
    },
  );

  testWidgets('blocks signup when the submit-time refresh fails', (
    tester,
  ) async {
    final service = _FakeLanternService(
      cachedUser: _anonymousUser,
      fetchResults: [right(_anonymousUser), left(_refreshFailure)],
    );
    final container = await _pumpAddEmail(tester, service);
    addTearDown(container.dispose);

    await tester.enterText(
      find.byKey(AuthKeys.signUpEmailField),
      'new@example.com',
    );
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(_continueButton()).onPressed,
      isNotNull,
    );
    await tester.tap(_continueButton());
    await tester.pumpAndSettle();

    expect(service.fetchCalls, 2);
    expect(service.signUpCalls, 0);
    expect(_emailField(tester).controller!.text, 'new@example.com');
    expect(
      find.byKey(AuthKeys.signUpAccountRefreshRetryButton),
      findsOneWidget,
    );
  });

  testWidgets('explicit different-account action performs logout rollover', (
    tester,
  ) async {
    final service = _FakeLanternService(
      cachedUser: _registeredUser,
      fetchResults: [right(_registeredUser), right(_registeredUser)],
    );
    final container = await _pumpAddEmail(tester, service);
    addTearDown(container.dispose);

    await tester.tap(find.byKey(AuthKeys.signUpUseDifferentAccountButton));
    await tester.pumpAndSettle();

    expect(service.logoutCalls, 1);
    expect(service.logoutEmail, 'backend@example.com');
    expect(container.read(homeProvider).value, _anonymousUser);
    expect(_emailField(tester).controller!.text, isEmpty);
    expect(find.byKey(AuthKeys.signUpUseDifferentAccountButton), findsNothing);
  });

  testWidgets('refreshes and reroutes after a signup conflict race', (
    tester,
  ) async {
    final conflict = Failure(
      error: 'user with this legacy user ID already exists',
      localizedErrorMessage: 'signup_error_user_exists',
    );
    final service = _FakeLanternService(
      cachedUser: _anonymousUser,
      fetchResults: [
        right(_anonymousUser),
        right(_anonymousUser),
        right(_registeredUser),
      ],
    )..signUpResult = left(conflict);
    final container = await _pumpAddEmail(tester, service);
    addTearDown(container.dispose);

    await tester.enterText(
      find.byKey(AuthKeys.signUpEmailField),
      'attempted@example.com',
    );
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(_continueButton()).onPressed,
      isNotNull,
    );
    await tester.tap(_continueButton());
    await tester.pumpAndSettle();

    expect(service.fetchCalls, 3);
    expect(service.signUpCalls, 1);
    expect(service.recoveryEmail, 'backend@example.com');
    expect(_emailField(tester).controller!.text, 'backend@example.com');
  });
}
