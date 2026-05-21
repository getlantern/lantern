import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/auth/confirm_email.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:loader_overlay/loader_overlay.dart';

class _RecordingAppRouter extends AppRouter {
  int popCount = 0;

  @override
  void pop<T extends Object?>([T? result]) {
    popCount += 1;
  }
}

class _FakeLanternService implements LanternService {
  int deleteAccountCalls = 0;

  @override
  Future<Either<Failure, UserResponseModel>> deleteAccount({
    required String email,
    required String password,
    bool isSSO = false,
  }) async {
    deleteAccountCalls += 1;
    return right(
      const UserResponseModel(
        legacyID: 0,
        legacyToken: '',
        emailConfirmed: false,
        success: true,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ConfirmEmail', () {
    late _RecordingAppRouter router;
    late _FakeLanternService lanternService;

    setUp(() async {
      await sl.reset();
      router = _RecordingAppRouter();
      lanternService = _FakeLanternService();
      sl.registerSingleton<AppRouter>(router);
    });

    tearDown(() async {
      await sl.reset();
    });

    Widget buildHarness() {
      return ProviderScope(
        overrides: [lanternServiceProvider.overrideWithValue(lanternService)],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          child: GlobalLoaderOverlay(
            child: MaterialApp(
              theme: AppTheme.appTheme(),
              home: const ConfirmEmail(
                email: 'person@example.com',
                password: 'temp-password',
                authFlow: AuthFlow.signUp,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('signup back press pops without deleting the account', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness());
      await tester.pump();

      await tester.tap(find.byType(BackButton));
      await tester.pump();

      expect(router.popCount, 1);
      expect(lanternService.deleteAccountCalls, 0);
    });

    testWidgets('system back press pops without deleting the account', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness());
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(router.popCount, 1);
      expect(lanternService.deleteAccountCalls, 0);
    });
  });
}
