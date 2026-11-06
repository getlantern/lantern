import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide Onboarding;
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/onboarding/onboarding.dart';

class _Settings extends AppSettingNotifier {
  @override
  AppSetting build() => AppSetting();
}

Future<void> _whatMakesLanternDifferent(
  WidgetTester tester, {
  required bool invites,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingProvider.overrideWith(_Settings.new),
        helperInvitesAvailableProvider.overrideWithValue(invites),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const Onboarding(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.byKey(const Key('onboarding.primary')));
  await tester.pumpAndSettle();
  expect(find.text('what_makes_lantern_different'.i18n), findsOneWidget);
}

void main() {
  setUpAll(Localization.loadTranslations);

  testWidgets('where Personal Proxies are offered, What makes Lantern '
      'different lists them with a New badge, before the nonprofit row', (
    tester,
  ) async {
    await _whatMakesLanternDifferent(tester, invites: true);
    final row = find.byKey(const Key('onboarding.personal_proxies'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.text('onboarding_personal_proxies'.i18n),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text('onboarding_personal_proxies_description'.i18n),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.byKey(const Key('onboarding.new_badge')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(row).dy,
      lessThan(tester.getTopLeft(find.text('nonprofit_mission'.i18n)).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('elsewhere the row is not shown', (tester) async {
    await _whatMakesLanternDifferent(tester, invites: false);
    expect(find.byKey(const Key('onboarding.personal_proxies')), findsNothing);
  });
}
