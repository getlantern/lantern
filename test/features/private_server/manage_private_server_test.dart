import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide ManagePrivateServer;
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/private_server/manage_private_server.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';

class _Servers extends AvailableServersNotifier {
  @override
  Future<AvailableServers> build() async => AvailableServers(const []);
}

class _Helpers extends HelpersNotifier {
  int refreshes = 0;

  @override
  HelpersState build() => const HelpersState(
    viewLoaded: true,
    view: HelpersView(
      unlocked: true,
      helpers: [HelperPairingView(pairingId: 'p1', name: 'Ali', online: true)],
    ),
  );
  @override
  Future<void> refreshIfUsed() async => refreshes++;
}

Future<void> _pump(
  WidgetTester tester, {
  required bool tab,
  _Helpers? helpers,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        availableServersProvider.overrideWith(_Servers.new),
        helpersProvider.overrideWith(() => helpers ?? _Helpers()),
        personalProxiesTabVisibleProvider.overrideWithValue(tab),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const ManagePrivateServer(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a third Personal Proxies tab while there is something to manage',
    (tester) async {
      await _pump(tester, tab: true);
      expect(find.text('manage_private_locations'.i18n), findsOneWidget);
      await tester.tap(find.byKey(const Key('manage.personal_proxies_tab')));
      await tester.pumpAndSettle();
      expect(find.text('Ali'), findsOneWidget);
      expect(find.byKey(const Key('personal_proxies.invite')), findsOneWidget);
    },
  );

  testWidgets('the Personal Proxies tab refreshes only once it is shown', (
    tester,
  ) async {
    final helpers = _Helpers();
    await _pump(tester, tab: true, helpers: helpers);
    expect(helpers.refreshes, 0, reason: 'My Servers is the tab shown');
    await tester.tap(find.byKey(const Key('manage.personal_proxies_tab')));
    await tester.pumpAndSettle();
    expect(helpers.refreshes, 1);
  });

  testWidgets('two tabs otherwise', (tester) async {
    await _pump(tester, tab: false);
    expect(find.byKey(const Key('manage.personal_proxies_tab')), findsNothing);
  });
}
