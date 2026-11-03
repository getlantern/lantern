import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/server_selection.dart';

Future<int Function()> _pump(
  WidgetTester tester, {
  required bool invites,
}) async {
  var invited = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [helperInvitesAvailableProvider.overrideWithValue(invites)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: Scaffold(
            body: PrivateLocationsMenu(onInvitePersonalProxy: () => invited++),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return () => invited;
}

void main() {
  testWidgets('offers "Invite a Personal Proxy" while invites are available', (
    tester,
  ) async {
    final invited = await _pump(tester, invites: true);
    expect(find.text('invite_personal_proxy'.i18n), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('server_selection.invite_personal_proxy')),
    );
    expect(invited(), 1);
  });

  testWidgets('no invite entry without helper invites (flag off or stealth)', (
    tester,
  ) async {
    await _pump(tester, invites: false);
    expect(
      find.byKey(const Key('server_selection.invite_personal_proxy')),
      findsNothing,
    );
  });

  testWidgets('"Manage Private Locations" replaces "Manage Private Servers"', (
    tester,
  ) async {
    await _pump(tester, invites: false);
    expect(find.text('manage_private_locations'.i18n), findsOneWidget);
    expect(find.text('manage_private_servers'.i18n), findsNothing);
  });
}
