import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/vpn/location_setting.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';

void main() {
  setUpAll(Localization.loadTranslations);

  testWidgets('the personal proxies group shows by name, with "Personal '
      'Proxy" under it and no place', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverLocationProvider.overrideWithValue(
            ServerLocation.personalProxy(),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: const Scaffold(body: LocationSetting()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('selected_location'.i18n), findsOneWidget);
    expect(find.text('your_personal_proxies'.i18n), findsOneWidget);
    expect(find.text('personal_proxy'.i18n), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('personal_proxy'.i18n)).dy,
      greaterThan(
        tester.getTopLeft(find.text('your_personal_proxies'.i18n)).dy,
      ),
    );
    expect(find.byType(Flag), findsNothing);
  });
}
