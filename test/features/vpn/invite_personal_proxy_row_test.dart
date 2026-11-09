import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide ServerSelection;
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/personal_proxy_status_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/server_selection.dart';

class _Helpers extends HelpersNotifier {
  _Helpers(this.helpers);
  final List<HelperPairingView> helpers;
  @override
  HelpersState build() => HelpersState(
    viewLoaded: true,
    view: HelpersView(unlocked: true, helpers: helpers),
  );
  @override
  Future<void> refreshIfUsed() async {}
}

class _Servers extends AvailableServersNotifier {
  @override
  Future<AvailableServers> build() async => AvailableServers([]);
  @override
  Future<void> refreshAvailableServersAfterProbeSettle() async {}
}

class _Status extends PersonalProxyStatusNotifier {
  @override
  Map<String, PersonalProxyStatus>? build() => null;
  @override
  Future<void> poll() async {}
}

const _sara = HelperPairingView(
  pairingId: 'p1',
  name: 'Sara',
  online: true,
  outboundTag: 'helper-0123456789ab',
);

Future<void> _pump(
  WidgetTester tester, {
  required List<HelperPairingView> helpers,
  bool invites = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        availableServersProvider.overrideWith(_Servers.new),
        helpersProvider.overrideWith(() => _Helpers(helpers)),
        personalProxyStatusProvider.overrideWith(_Status.new),
        serverLocationProvider.overrideWithValue(
          ServerLocation(
            serverName: '',
            serverType: ServerLocationType.auto.name,
          ),
        ),
        isUserProProvider.overrideWithValue(false),
        helperInvitesAvailableProvider.overrideWithValue(invites),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const ServerSelection(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(Localization.loadTranslations);

  final row = find.byKey(const Key('server_selection.invite_row'));
  final groupRow = find.byKey(
    const Key('server_selection.personal_proxies.invite'),
  );

  testWidgets('before any personal proxy, Invite a Personal Proxy sits under '
      'Smart Location, above the Pro upsell, and starts an invite', (
    tester,
  ) async {
    await _pump(tester, helpers: const []);
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.text('invite_personal_proxy'.i18n),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.byKey(const Key('server_selection.smart_location')),
            )
            .dy,
      ),
    );
    expect(
      tester.getBottomLeft(row).dy,
      lessThan(tester.getTopLeft(find.byType(ProBanner)).dy),
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    // The invite starts by asking the name the friend knows the user by.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('invite_personal_proxy'.i18n),
      ),
      findsOneWidget,
    );
  });

  testWidgets('where helper invites are not offered there is no row', (
    tester,
  ) async {
    await _pump(tester, helpers: const [], invites: false);
    expect(row, findsNothing);
  });

  testWidgets('once a personal proxy exists the row moves to the end of the '
      'Personal Proxies group under Private Locations', (tester) async {
    await _pump(tester, helpers: const [_sara]);
    expect(row, findsNothing);
    await tester.tap(
      find.byKey(const Key('server_selection.private_servers_tab')),
    );
    await tester.pumpAndSettle();
    expect(groupRow, findsOneWidget);
    expect(
      tester.getTopLeft(groupRow).dy,
      greaterThan(
        tester
            .getBottomLeft(
              find.byKey(const Key('server_selection.personal_proxy.p1')),
            )
            .dy,
      ),
    );
  });

  testWidgets('the group has no invite row where helper invites are not '
      'offered', (tester) async {
    await _pump(tester, helpers: const [_sara], invites: false);
    await tester.tap(
      find.byKey(const Key('server_selection.private_servers_tab')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('server_selection.personal_proxy.p1')),
      findsOneWidget,
    );
    expect(groupRow, findsNothing);
  });
}
