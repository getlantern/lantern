import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/router/router.dart' as routes;
import 'package:lantern/core/router/router.gr.dart' as pages;
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/widgets/oauth_login.dart';
import 'package:lantern/features/account/account.dart';
import 'package:lantern/features/auth/add_email.dart';
import 'package:lantern/features/auth/confirm_email.dart';
import 'package:lantern/features/auth/create_password.dart';
import 'package:lantern/features/auth/reset_password_email.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/plans/provider/payment_notifier.dart';
import 'package:lantern/features/setting/setting.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

const _placeholder = 'support+123@getlantern.org';
const _email = 'person@example.com';
const _password = 'New-password-123!';

UserResponseModel _user(
  String email, {
  bool registered = true,
  String userLevel = 'pro',
}) => UserResponseModel(
  legacyID: 123,
  legacyToken: 'test-token',
  emailConfirmed: true,
  success: true,
  legacyUserData: UserDataModel(
    userId: 123,
    email: email,
    userLevel: userLevel,
    unpassRegistered: registered,
  ),
);

class _Router extends routes.AppRouter {
  final pushed = <PageRouteInfo>[];
  int rootPops = 0;
  int pops = 0;

  @override
  void pop<T extends Object?>([T? result]) => pops++;

  @override
  void popUntilRoot() => rootPops++;

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route);
    return null;
  }
}

class _Settings extends AppSettingNotifier {
  @override
  AppSetting build() => const AppSetting(userLoggedIn: false);

  @override
  void setUserLoggedIn(bool value) {
    state = state.copyWith(userLoggedIn: value);
  }
}

class _Service implements LanternService {
  UserResponseModel user = _user(_placeholder);
  Completer<void>? ready;
  Completer<Either<Failure, UserResponseModel>>? pendingUserRead;
  int userReads = 0;
  int loginCalls = 0;
  final oAuthCallbacks = <String>[];
  final starts = <String>[];
  final completions = <({String email, String password, String code})>[];
  final recoveries = <String>[];
  final changes = <({String email, String password})>[];
  bool rejectCode = false;
  bool loginRequired = false;

  @override
  Future<void> waitForRadiance() => ready?.future ?? Future.value();

  @override
  Future<Either<Failure, UserResponseModel>> getUserData() async {
    userReads++;
    if (pendingUserRead != null) return pendingUserRead!.future;
    return right(user);
  }

  @override
  Future<Either<Failure, DataCapUsageResponse>> getDataCapInfo() async =>
      right(DataCapUsageResponse(enabled: false));

  @override
  Future<Either<Failure, String>> featureFlag() async => right('{}');

  @override
  Future<Either<Failure, UserResponseModel>> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    return right(user);
  }

  @override
  Future<Either<Failure, UserResponseModel>> oAuthLoginCallback(
    String token,
  ) async {
    oAuthCallbacks.add(token);
    return right(user);
  }

  @override
  Future<Either<Failure, Unit>> startBindLegacyEmail(String email) async {
    starts.add(email);
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> completeBindLegacyEmail({
    required String email,
    required String password,
    required String code,
  }) async {
    completions.add((email: email, password: password, code: code));
    if (loginRequired) {
      return left(
        Failure(
          error: 'legacy_email_bound_login_required: connection refused',
          localizedErrorMessage: 'Could not connect',
        ),
      );
    }
    if (rejectCode) {
      return left(
        Failure(error: 'invalid_code', localizedErrorMessage: 'Invalid code'),
      );
    }
    user = _user(email, userLevel: user.legacyUserData.userLevel);
    return right(unit);
  }

  @override
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email) async {
    recoveries.add(email);
    return right(unit);
  }

  @override
  Future<Either<Failure, String>> startChangeEmail(
    String email,
    String password,
  ) async {
    changes.add((email: email, password: password));
    return right(email);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Localization.loadTranslations);
  late _Router router;
  late _Service service;
  late ProviderContainer container;

  setUp(() async {
    await sl.reset();
    router = _Router();
    service = _Service();
    sl.registerSingleton<routes.AppRouter>(router);
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        appSettingProvider.overrideWith(_Settings.new),
        isOAuthLoginProvider.overrideWith((ref) async => false),
        helperEntryVisibleProvider.overrideWithValue(false),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await sl.reset();
  });

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    bool waitForUser = true,
  }) async {
    if (waitForUser) await container.read(homeProvider.future);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          child: GlobalLoaderOverlay(
            child: MaterialApp(theme: AppTheme.appTheme(), home: screen),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'Account offers Add email without exposing the placeholder or requiring the login UI flag',
    (tester) async {
      await mount(tester, const Account());
      expect(find.text(_placeholder), findsNothing);
      expect(find.text('change_email'.i18n), findsNothing);
      await tester.tap(find.text('add_email'.i18n));
      expect(
        (router.pushed.single.args as pages.AddEmailArgs).authFlow,
        AuthFlow.bindLegacyEmail,
      );
      expect(container.read(appSettingProvider).userLoggedIn, isFalse);
    },
  );

  testWidgets('placeholder setup does not hide Settings sign-in actions', (
    tester,
  ) async {
    service.user = _user(_placeholder, registered: false);
    await mount(tester, const Setting());
    expect(find.byKey(const Key('setting.account_tile')), findsOneWidget);
    expect(find.byKey(const Key('setting.sign_in_tile')), findsOneWidget);
    expect(
      find.byKey(const Key('setting.authorize_device_tile')),
      findsOneWidget,
    );
    expect(find.text(_placeholder), findsNothing);
    expect(container.read(appSettingProvider).userLoggedIn, isFalse);
  });

  testWidgets('email and OAuth stay unavailable until account data loads', (
    tester,
  ) async {
    service.ready = Completer<void>();
    await mount(tester, const AddEmail(), waitForUser: false);
    await tester.enterText(find.byType(TextFormField), _email);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<PrimaryButton>(find.byKey(AuthKeys.signUpContinueButton))
          .enabled,
      isFalse,
    );
    expect(find.byType(OAuthLogin), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(router.pushed, isEmpty);
    expect(service.starts, isEmpty);
    expect(service.recoveries, isEmpty);
    expect(service.oAuthCallbacks, isEmpty);

    service.ready!.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byKey(AuthKeys.signUpContinueButton));
    await tester.pump();
    final args = router.pushed.single.args as pages.CreatePasswordArgs;
    expect(args.authFlow, AuthFlow.bindLegacyEmail);
    expect(find.byType(OAuthLogin), findsNothing);
  });

  testWidgets(
    'account lookup failure offers a retry before signup can resume',
    (tester) async {
      service.pendingUserRead = Completer<Either<Failure, UserResponseModel>>();
      await mount(tester, const AddEmail(), waitForUser: false);
      await tester.enterText(find.byType(TextFormField), _email);
      service.pendingUserRead!.complete(
        left(Failure(error: 'offline', localizedErrorMessage: 'Offline')),
      );
      await tester.pumpAndSettle();
      expect(find.text('retry'.i18n), findsOneWidget);
      expect(find.byType(OAuthLogin), findsNothing);
      expect(
        tester
            .widget<PrimaryButton>(find.byKey(AuthKeys.signUpContinueButton))
            .enabled,
        isFalse,
      );
      expect(router.pushed, isEmpty);
      service.pendingUserRead = null;
      await tester.tap(find.text('retry'.i18n));
      await tester.pumpAndSettle();
      expect(find.text('retry'.i18n), findsNothing);
      await tester.tap(find.byKey(AuthKeys.signUpContinueButton));
      await tester.pumpAndSettle();
      expect(
        (router.pushed.single.args as pages.CreatePasswordArgs).authFlow,
        AuthFlow.bindLegacyEmail,
      );
      expect(service.loginCalls, 0);
      expect(service.recoveries, isEmpty);
    },
  );

  for (final (invalidate, fail) in [
    (false, false),
    (true, false),
    (true, true),
  ]) {
    testWidgets(
      'refresh blocks stale account actions: invalidate=$invalidate, fail=$fail',
      (tester) async {
        service.user = _user('', registered: false, userLevel: 'free');
        await mount(tester, const AddEmail());
        final oauth = tester.widget<OAuthLogin>(find.byType(OAuthLogin).first);
        await tester.enterText(find.byType(TextFormField), _email);
        service.pendingUserRead =
            Completer<Either<Failure, UserResponseModel>>();
        final Future<void> refresh;
        if (invalidate) {
          container.invalidate(homeProvider);
          refresh = container.read(homeProvider.future);
          expect(container.read(homeProvider).asData, isNotNull);
        } else {
          refresh = container.read(homeProvider.notifier).refreshUser();
        }
        await tester.pump();
        expect(container.read(homeProvider).isLoading, isTrue);
        expect(find.byType(OAuthLogin), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester
              .widget<PrimaryButton>(find.byKey(AuthKeys.signUpContinueButton))
              .enabled,
          isFalse,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        oauth.onResult({'token': 'callback-while-loading'});
        await tester.pump();
        expect(service.oAuthCallbacks, isEmpty);
        expect(router.pushed, isEmpty);
        expect(container.read(appSettingProvider).userLoggedIn, isFalse);
        final completed = fail
            ? expectLater(refresh, throwsException)
            : refresh;
        service.pendingUserRead!.complete(
          fail
              ? left(
                  Failure(error: 'offline', localizedErrorMessage: 'Offline'),
                )
              : right(service.user),
        );
        await completed;
        await tester.pump();
        if (fail) {
          expect(container.read(homeProvider).hasValue, isTrue);
          expect(container.read(homeProvider).hasError, isTrue);
          expect(find.text('retry'.i18n), findsOneWidget);
          expect(find.byType(OAuthLogin), findsNothing);
          expect(
            tester
                .widget<PrimaryButton>(
                  find.byKey(AuthKeys.signUpContinueButton),
                )
                .enabled,
            isFalse,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          oauth.onResult({'token': 'callback-after-error'});
          await tester.pump();
          expect(service.oAuthCallbacks, isEmpty);
          expect(router.pushed, isEmpty);
        } else {
          expect(find.byType(OAuthLogin), findsNWidgets(2));
        }
      },
    );
  }

  for (final registered in [false, true]) {
    testWidgets(
      'placeholder AddEmail uses binding when registered=$registered',
      (tester) async {
        service.user = _user(_placeholder, registered: registered);
        await mount(tester, const AddEmail());
        expect(find.text(_placeholder), findsNothing);
        expect(find.byType(OAuthLogin), findsNothing);
        expect(
          find.byKey(AuthKeys.signUpContinueWithoutEmailButton),
          findsNothing,
        );
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          isEmpty,
        );
        await tester.enterText(find.byType(TextFormField), _email);
        await tester.pump();
        await tester.tap(find.byKey(AuthKeys.signUpContinueButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final args = router.pushed.single.args as pages.CreatePasswordArgs;
        expect(args.email, _email);
        expect(args.authFlow, AuthFlow.bindLegacyEmail);
        expect(args.bindingOrigin, AuthFlow.signUp);
        expect(service.starts, isEmpty);
        expect(service.recoveries, isEmpty);
        expect(
          container.read(homeProvider).value?.legacyUserData.email,
          _placeholder,
        );
      },
    );
  }

  testWidgets(
    'choosing a password starts binding, with no recovery or account mutation',
    (tester) async {
      await mount(
        tester,
        const CreatePassword(
          email: _email,
          authFlow: AuthFlow.bindLegacyEmail,
          code: '',
        ),
      );
      await tester.enterText(find.byType(TextFormField), _password);
      await tester.pump();
      await tester.tap(find.byKey(AuthKeys.createPasswordContinueButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.starts, [_email]);
      expect(service.completions, isEmpty);
      expect(service.recoveries, isEmpty);
      final args = router.pushed.single.args as pages.ConfirmEmailArgs;
      expect(args.email, _email);
      expect(args.password, _password);
      expect(args.authFlow, AuthFlow.bindLegacyEmail);
      expect(container.read(appSettingProvider).userLoggedIn, isFalse);
      expect(
        container.read(homeProvider).value?.legacyUserData.email,
        _placeholder,
      );
    },
  );

  testWidgets(
    'binding resend and completion use only the dedicated endpoints',
    (tester) async {
      container.read(paymentSessionProvider.notifier).markRedirectInitiated();
      await mount(
        tester,
        const ConfirmEmail(
          email: _email,
          password: _password,
          authFlow: AuthFlow.bindLegacyEmail,
        ),
      );
      await tester.tap(find.byKey(AuthKeys.confirmEmailResendButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.starts, [_email]);
      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.completions, [
        (email: _email, password: _password, code: '123456'),
      ]);
      expect(service.recoveries, isEmpty);
      expect(service.userReads, 2);
      final user = container.read(homeProvider).value!;
      expect(user.legacyID, 123);
      expect(user.legacyToken, 'test-token');
      expect(user.legacyUserData.email, _email);
      expect(container.read(appSettingProvider).userLoggedIn, isTrue);
      expect(container.read(paymentSessionProvider), isFalse);
      expect(find.text('email_updated'.i18n), findsOneWidget);
      await tester.tap(find.text('ok'.i18n));
      await tester.pumpAndSettle();
      expect(router.rootPops, 1);
      expect(router.pushed.single, isA<pages.Account>());
    },
  );

  testWidgets(
    'rejected binding code keeps the existing account and login state',
    (tester) async {
      service.rejectCode = true;
      container.read(paymentSessionProvider.notifier).markRedirectInitiated();
      await mount(
        tester,
        const ConfirmEmail(
          email: _email,
          password: _password,
          authFlow: AuthFlow.bindLegacyEmail,
        ),
      );
      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.userReads, 1);
      expect(container.read(appSettingProvider).userLoggedIn, isFalse);
      expect(container.read(paymentSessionProvider), isTrue);
      expect(
        container.read(homeProvider).value?.legacyUserData.email,
        _placeholder,
      );
      expect(find.text('Invalid code'), findsOneWidget);
    },
  );

  for (final loggedIn in [false, true]) {
    testWidgets(
      'completed binding retries the identity-checked endpoint when loggedIn=$loggedIn',
      (tester) async {
        service.loginRequired = true;
        container.read(paymentSessionProvider.notifier).markRedirectInitiated();
        container.read(appSettingProvider.notifier).setUserLoggedIn(loggedIn);
        await mount(
          tester,
          const ConfirmEmail(
            email: _email,
            password: _password,
            authFlow: AuthFlow.bindLegacyEmail,
          ),
        );
        final originalUser = container.read(homeProvider).value;
        await tester.enterText(find.byType(EditableText), '123456');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.textContaining('email_updated'.i18n), findsOneWidget);
        expect(find.textContaining('Could not connect'), findsOneWidget);
        expect(service.userReads, 1);
        expect(container.read(homeProvider).value, same(originalUser));
        expect(container.read(appSettingProvider).userLoggedIn, loggedIn);
        expect(container.read(paymentSessionProvider), isTrue);

        service.loginRequired = false;
        await tester.tap(find.text('retry'.i18n));
        await tester.pumpAndSettle();
        expect(router.pushed, isEmpty);
        expect(router.rootPops, 0);
        expect(service.loginCalls, 0);
        expect(service.completions, [
          (email: _email, password: _password, code: '123456'),
          (email: _email, password: _password, code: '123456'),
        ]);
        expect(service.starts, isEmpty);
        expect(service.recoveries, isEmpty);
        expect(service.userReads, 2);
        final user = container.read(homeProvider).value!;
        expect(user.legacyID, originalUser!.legacyID);
        expect(user.legacyToken, originalUser.legacyToken);
        expect(user.legacyUserData.email, _email);
        expect(container.read(appSettingProvider).userLoggedIn, isTrue);
        expect(container.read(paymentSessionProvider), isFalse);
      },
    );
  }

  testWidgets(
    'cancelling a bound-email retry preserves the account and session',
    (tester) async {
      service.loginRequired = true;
      container.read(paymentSessionProvider.notifier).markRedirectInitiated();
      await mount(
        tester,
        const ConfirmEmail(
          email: _email,
          password: _password,
          authFlow: AuthFlow.bindLegacyEmail,
        ),
      );
      final originalUser = container.read(homeProvider).value;
      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pumpAndSettle();
      await tester.tap(find.text('cancel'.i18n));
      await tester.pumpAndSettle();
      expect(find.text('retry'.i18n), findsNothing);
      expect(service.completions, hasLength(1));
      expect(service.loginCalls, 0);
      expect(service.userReads, 1);
      expect(container.read(homeProvider).value, same(originalUser));
      expect(container.read(appSettingProvider).userLoggedIn, isFalse);
      expect(container.read(paymentSessionProvider), isTrue);
      expect(router.pushed, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(router.pops, 1);
      expect(container.read(homeProvider).value, same(originalUser));
    },
  );

  for (final origin in [AuthFlow.signUp, AuthFlow.lanternProLicense]) {
    testWidgets('binding resumes ${origin.name} without restarting signup', (
      tester,
    ) async {
      const licenseKey = 'ABCDE-FGHIJ-KLMNO-PQRST-UVWXY';
      service.user = _user(_placeholder, registered: false, userLevel: 'free');
      container.read(paymentSessionProvider.notifier).markRedirectInitiated();
      await mount(tester, AddEmail(authFlow: origin, licenseKey: licenseKey));
      await tester.enterText(find.byType(TextFormField), _email);
      await tester.pump();
      await tester.tap(find.byKey(AuthKeys.signUpContinueButton));
      await tester.pumpAndSettle();
      final create = router.pushed.last.args as pages.CreatePasswordArgs;
      expect(create.bindingOrigin, origin);
      expect(create.licenseKey, licenseKey);
      await mount(
        tester,
        CreatePassword(
          email: create.email,
          authFlow: create.authFlow,
          code: create.code,
          bindingOrigin: create.bindingOrigin,
          licenseKey: create.licenseKey,
        ),
      );
      await tester.enterText(find.byType(TextFormField), _password);
      await tester.pump();
      await tester.tap(find.byKey(AuthKeys.createPasswordContinueButton));
      await tester.pumpAndSettle();
      final confirm = router.pushed.last.args as pages.ConfirmEmailArgs;
      expect(confirm.bindingOrigin, origin);
      expect(confirm.licenseKey, licenseKey);
      await mount(
        tester,
        ConfirmEmail(
          email: confirm.email,
          password: confirm.password,
          authFlow: confirm.authFlow,
          bindingOrigin: confirm.bindingOrigin,
          licenseKey: confirm.licenseKey,
        ),
      );
      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pumpAndSettle();
      await tester.tap(find.text('ok'.i18n));
      await tester.pumpAndSettle();
      expect(router.rootPops, 1);
      if (origin == AuthFlow.signUp) {
        final checkout =
            router.pushed.last.args as pages.ChoosePaymentMethodArgs;
        expect(checkout.email, _email);
        expect(checkout.authFlow, AuthFlow.renewSubscription);
        expect(checkout.code, isNull);
      } else {
        final license = router.pushed.last.args as pages.LanternProLicenseArgs;
        expect(license.email, _email);
        expect(license.code, isEmpty);
        expect(license.licenseKey, licenseKey);
      }
      expect(service.recoveries, isEmpty);
      expect(service.loginCalls, 0);
      expect(service.completions, hasLength(1));
      expect(container.read(homeProvider).value!.legacyID, 123);
      expect(container.read(homeProvider).value!.legacyToken, 'test-token');
      expect(container.read(homeProvider).value!.legacyUserData.email, _email);
      expect(container.read(appSettingProvider).userLoggedIn, isTrue);
      expect(container.read(paymentSessionProvider), isFalse);
    });
  }

  testWidgets('real email keeps the existing password-verified change flow', (
    tester,
  ) async {
    service.user = _user('old@example.com');
    await mount(
      tester,
      const AddEmail(authFlow: AuthFlow.changeEmail, password: 'old-password'),
    );
    await tester.enterText(find.byType(TextFormField), _email);
    await tester.pump();
    await tester.tap(find.byKey(AuthKeys.signUpContinueButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(service.changes, [(email: _email, password: 'old-password')]);
    expect(
      (router.pushed.single.args as pages.ConfirmEmailArgs).authFlow,
      AuthFlow.changeEmail,
    );
    expect(service.starts, isEmpty);
  });

  testWidgets(
    'recovery does not prefill or submit a reserved placeholder address',
    (tester) async {
      await mount(tester, const ResetPasswordEmail(email: _placeholder));
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        isEmpty,
      );
      await tester.enterText(find.byType(TextFormField), _placeholder);
      await tester.pump();
      expect(
        tester
            .widget<PrimaryButton>(
              find.byKey(AuthKeys.resetPasswordEmailNextButton),
            )
            .enabled,
        isFalse,
      );
      expect(service.recoveries, isEmpty);
      await tester.enterText(find.byType(TextFormField), _email);
      await tester.pump();
      await tester.tap(find.byKey(AuthKeys.resetPasswordEmailNextButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(service.recoveries, [_email]);
      expect(
        (router.pushed.single.args as pages.ConfirmEmailArgs).authFlow,
        AuthFlow.resetPassword,
      );
    },
  );
}
