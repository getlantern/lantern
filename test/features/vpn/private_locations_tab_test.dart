import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/personal_proxies_section.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/server_selection.dart';

class _Helpers extends HelpersNotifier {
  _Helpers(this.initial);
  final HelpersState initial;
  @override
  HelpersState build() => initial;
  @override
  Future<void> refreshIfUsed() async {}
}

class _NoServers extends AvailableServersNotifier {
  @override
  Future<AvailableServers> build() async => AvailableServers([]);
}

Future<void> _pump(WidgetTester tester, List<HelperPairingView> helpers) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        availableServersProvider.overrideWith(_NoServers.new),
        helpersProvider.overrideWith(
          () => _Helpers(
            HelpersState(
              viewLoaded: true,
              view: HelpersView(unlocked: true, helpers: helpers),
            ),
          ),
        ),
        serverLocationProvider.overrideWithValue(
          ServerLocation(
            serverName: '',
            serverType: ServerLocationType.auto.name,
          ),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const Scaffold(body: PrivateServerLocationListView()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('personal proxies alone fill the Private Locations tab', (
    tester,
  ) async {
    await _pump(tester, const [
      HelperPairingView(pairingId: 'p1', name: 'Ali', online: true),
    ]);
    expect(find.byType(PersonalProxiesSection), findsOneWidget);
    expect(
      find.byKey(const Key('server_selection.personal_proxies')),
      findsOneWidget,
    );
    expect(find.text('no_private_server_setup_yet'.i18n), findsNothing);
  });

  testWidgets('the empty state shows without servers or personal proxies', (
    tester,
  ) async {
    await _pump(tester, const []);
    expect(find.text('no_private_server_setup_yet'.i18n), findsOneWidget);
    expect(
      find.byKey(const Key('server_selection.personal_proxies')),
      findsNothing,
    );
  });
}
