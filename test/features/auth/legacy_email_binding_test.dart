import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
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
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

const _placeholder = 'support+123@getlantern.org';
const _email = 'person@example.com';
const _password = 'New-password-123!';

UserResponseModel _user(String email, {bool registered = true}) =>
    UserResponseModel(
      legacyID: 123,
      legacyToken: 'test-token',
      emailConfirmed: true,
      success: true,
      legacyUserData: UserDataModel(
        userId: 123,
        email: email,
        userLevel: 'pro',
        unpassRegistered: registered,
      ),
    );

class _Router extends routes.AppRouter {
  final pushed = <PageRouteInfo>[];

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route);
    return null;
  }
}

class _Home extends HomeNotifier {
  _Home(this.user);
  final UserResponseModel user;
  int refreshes = 0;

  @override
  Future<UserResponseModel> build() async => user;

  @override
  Future<void> reloadUserData() async {
    refreshes++;
    state = AsyncData(_user(_email));
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
  final starts = <String>[];
  final completions = <({String email, String password, String code})>[];
  final recoveries = <String>[];
  final changes = <({String email, String password})>[];
  bool rejectCode = false;

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
    return rejectCode
        ? left(
            Failure(
              error: 'invalid_code',
              localizedErrorMessage: 'Invalid code',
            ),
          )
        : right(unit);
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
  late _Home home;
  late ProviderContainer container;

  setUp(() async {
    await sl.reset();
    router = _Router();
    service = _Service();
    home = _Home(_user(_placeholder));
    sl.registerSingleton<routes.AppRouter>(router);
    container = ProviderContainer(
      overrides: [
        lanternServiceProvider.overrideWithValue(service),
        homeProvider.overrideWith(() => home),
        appSettingProvider.overrideWith(_Settings.new),
        isOAuthLoginProvider.overrideWith((ref) async => false),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await sl.reset();
  });

  Future<void> mount(WidgetTester tester, Widget screen) async {
    await container.read(homeProvider.future);
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

  for (final registered in [false, true]) {
    testWidgets(
      'placeholder AddEmail uses binding when registered=$registered',
      (tester) async {
        home = _Home(_user(_placeholder, registered: registered));
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
      expect(home.refreshes, 1);
      final user = container.read(homeProvider).value!;
      expect(user.legacyID, 123);
      expect(user.legacyToken, 'test-token');
      expect(user.legacyUserData.email, _email);
      expect(container.read(appSettingProvider).userLoggedIn, isTrue);
      expect(find.text('email_updated'.i18n), findsOneWidget);
    },
  );

  testWidgets(
    'rejected binding code keeps the existing account and login state',
    (tester) async {
      service.rejectCode = true;
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
      expect(home.refreshes, 0);
      expect(container.read(appSettingProvider).userLoggedIn, isFalse);
      expect(
        container.read(homeProvider).value?.legacyUserData.email,
        _placeholder,
      );
      expect(find.text('Invalid code'), findsOneWidget);
    },
  );

  testWidgets('real email keeps the existing password-verified change flow', (
    tester,
  ) async {
    home = _Home(_user('old@example.com'));
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
