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
  @override
  HelpersState build() => const HelpersState(
    viewLoaded: true,
    view: HelpersView(
      unlocked: true,
      helpers: [
        HelperPairingView(
          pairingId: 'p1',
          name: 'Sara',
          online: true,
          outboundTag: 'helper-0123456789ab',
        ),
      ],
    ),
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

Future<void> _pump(WidgetTester tester, ServerLocation selected) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        availableServersProvider.overrideWith(_Servers.new),
        helpersProvider.overrideWith(_Helpers.new),
        personalProxyStatusProvider.overrideWith(_Status.new),
        serverLocationProvider.overrideWithValue(selected),
        isUserProProvider.overrideWithValue(false),
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

  Finder inCard(Finder f) => find.descendant(
    of: find.byKey(const Key('server_selection.smart_location')),
    matching: f,
    matchRoot: true,
  );

  testWidgets('with a friend selected the Smart Location card shows only the '
      'generic Smart Location: no friend, flag, place or protocol', (
    tester,
  ) async {
    await _pump(
      tester,
      ServerLocation.personalProxy(friendTag: 'helper-0123456789ab').copyWith(
        autoLocation: const AutoLocation(
          country: 'Germany',
          countryCode: 'DE',
          displayName: 'Germany - Berlin',
          tag: 'samizdat-1',
        ),
      ),
    );
    expect(inCard(find.text('fastest_server'.i18n)), findsOneWidget);
    expect(inCard(find.text('Sara')), findsNothing);
    expect(inCard(find.text('personal_proxy'.i18n)), findsNothing);
    expect(inCard(find.text('Germany - Berlin')), findsNothing);
    expect(inCard(find.text('Samizdat')), findsNothing);
    expect(inCard(find.byType(Flag)), findsNothing);
  });

  testWidgets('otherwise it shows the auto location as before', (tester) async {
    await _pump(
      tester,
      ServerLocation.personalProxy().copyWith(
        autoLocation: const AutoLocation(
          country: 'Germany',
          countryCode: 'DE',
          displayName: 'Germany - Berlin',
          tag: 'samizdat-1',
        ),
      ),
    );
    expect(inCard(find.text('Germany - Berlin')), findsOneWidget);
    expect(inCard(find.text('Samizdat')), findsOneWidget);
    expect(inCard(find.byType(Flag)), findsOneWidget);
    expect(inCard(find.text('Sara')), findsNothing);
  });
}
