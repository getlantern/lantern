import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide DeleteAccount;
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/core/widgets/oauth_login.dart';
import 'package:lantern/features/account/delete_account.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';

void main() {
  tearDown(() => PlatformUtils.isTv = false);

  Future<void> pumpDeleteAccount(WidgetTester tester, {required bool sso}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSSOUserProvider.overrideWith((ref) async => sso),
          oAuthProviderProvider.overrideWith((ref) async => 'google'),
        ],
        child: ScreenUtilInit(
          designSize: mobileSize,
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: const DeleteAccount(),
          ),
        ),
      ),
    );
  }

  for (final tv in [true, false]) {
    testWidgets('SSO verify button ${tv ? 'is hidden' : 'shows'} '
        'when isTv=$tv', (tester) async {
      PlatformUtils.isTv = tv;
      await pumpDeleteAccount(tester, sso: true);
      await tester.pumpAndSettle();

      expect(find.byType(OAuthLogin), tv ? findsNothing : findsOneWidget);
      expect(find.byKey(AuthKeys.deleteAccountConfirmButton), findsNothing);
    });
  }

  testWidgets('password accounts can still delete on TV', (tester) async {
    PlatformUtils.isTv = true;
    await pumpDeleteAccount(tester, sso: false);
    await tester.pumpAndSettle();

    expect(find.byKey(AuthKeys.deleteAccountConfirmButton), findsOneWidget);
  });
}
