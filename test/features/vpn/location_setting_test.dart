import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/location_setting.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';

class _Helpers extends HelpersNotifier {
  _Helpers(this.initial);
  final HelpersState initial;
  @override
  HelpersState build() => initial;
}

const _tag = 'helper-0123456789ab';

Future<void> _pumpFriend(
  WidgetTester tester,
  List<HelperPairingView> helpers,
) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      serverLocationProvider.overrideWithValue(
        ServerLocation.personalProxy(friendTag: _tag),
      ),
      helpersProvider.overrideWith(
        () => _Helpers(
          HelpersState(
            viewLoaded: true,
            view: HelpersView(unlocked: true, helpers: helpers),
          ),
        ),
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

void main() {
  setUpAll(Localization.loadTranslations);

  testWidgets('a friend selected alone shows by name, with "Personal Proxy" '
      'under it, and no flag or place', (tester) async {
    await _pumpFriend(tester, const [
      HelperPairingView(
        pairingId: 'p0',
        name: 'Bo',
        outboundTag: 'helper-ffffffffffff',
      ),
      HelperPairingView(pairingId: 'p1', name: 'Sara', outboundTag: _tag),
    ]);
    await tester.pump();
    expect(find.text('selected_location'.i18n), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('Bo'), findsNothing);
    expect(find.text('your_personal_proxies'.i18n), findsNothing);
    expect(find.text('personal_proxy'.i18n), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('personal_proxy'.i18n)).dy,
      greaterThan(tester.getTopLeft(find.text('Sara')).dy),
    );
    expect(find.byType(Flag), findsNothing);
  });

  testWidgets('a friend the view does not know shows the generic helper name', (
    tester,
  ) async {
    await _pumpFriend(tester, const []);
    await tester.pump();
    expect(find.text('helper_unnamed'.i18n), findsOneWidget);
    expect(find.byType(Flag), findsNothing);
  });

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
