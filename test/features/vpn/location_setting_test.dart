import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/vpn/location_setting.dart';
import 'package:lantern/features/vpn/provider/personal_proxy_status_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

class _Helpers extends HelpersNotifier {
  _Helpers(this.initial);
  final HelpersState initial;
  @override
  HelpersState build() => initial;
}

class _Status extends PersonalProxyStatusNotifier {
  _Status(this.initial);
  final Map<String, PersonalProxyStatus>? initial;
  int polls = 0;
  @override
  Map<String, PersonalProxyStatus>? build() => initial;
  @override
  Future<void> poll() async => polls++;
}

const _tag = 'helper-0123456789ab';

Future<void> _pumpFriend(
  WidgetTester tester,
  List<HelperPairingView> helpers, {
  VPNStatus vpn = VPNStatus.disconnected,
  _Status? status,
}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      vpnProvider.overrideWithValue(vpn),
      personalProxyStatusProvider.overrideWith(() => status ?? _Status(null)),
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
          vpnProvider.overrideWithValue(VPNStatus.disconnected),
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
  group("the selected friend's rooms path", () {
    const sara = [
      HelperPairingView(
        pairingId: 'p1',
        name: 'Sara',
        online: true,
        outboundTag: _tag,
      ),
    ];
    late final connecting = 'personal_proxy_path_connecting'.i18n;
    late final reconnecting = 'personal_proxy_path_reconnecting'.i18n;
    late final unavailable = 'personal_proxy_path_unavailable'.i18n;

    Future<void> pumpPath(
      WidgetTester tester,
      String? path, {
      VPNStatus vpn = VPNStatus.connected,
      bool direct = false,
      bool reverse = false,
    }) async {
      // A new scope each time: a scope keeps its first overrides.
      await tester.pumpWidget(const SizedBox());
      await _pumpFriend(
        tester,
        sara,
        vpn: vpn,
        status: _Status({
          _tag: PersonalProxyStatus(
            direct: direct,
            reverse: reverse,
            rooms: true,
            roomsPath: path,
          ),
        }),
      );
      await tester.pump();
    }

    testWidgets('shows while it is not up, under "Personal Proxy"', (
      tester,
    ) async {
      await pumpPath(tester, PersonalProxyStatus.pathConnecting);
      expect(find.text(connecting), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(connecting)).dy,
        greaterThan(tester.getTopLeft(find.text('personal_proxy'.i18n)).dy),
      );

      await pumpPath(tester, PersonalProxyStatus.pathReconnecting);
      expect(find.text(reconnecting), findsOneWidget);

      await pumpPath(tester, PersonalProxyStatus.pathUnavailable);
      expect(find.text(unavailable), findsOneWidget);
      final context = tester.element(find.text(unavailable));
      expect(
        tester.widget<Text>(find.text(unavailable)).style?.color,
        context.statusErrorText,
      );
    });

    testWidgets('is hidden while connected, unknown, unreported, or with the '
        'VPN off', (tester) async {
      Future<void> expectNone() async {
        expect(find.text(connecting), findsNothing);
        expect(find.text(reconnecting), findsNothing);
        expect(find.text(unavailable), findsNothing);
      }

      await pumpPath(tester, PersonalProxyStatus.pathConnected);
      await expectNone();
      await pumpPath(tester, PersonalProxyStatus.pathUnknown);
      await expectNone();
      await pumpPath(tester, null);
      await expectNone();
      await pumpPath(
        tester,
        PersonalProxyStatus.pathUnavailable,
        vpn: VPNStatus.disconnected,
      );
      await expectNone();
    });

    testWidgets('is hidden while a direct or reverse route carries the '
        'friend, whatever the rooms path', (tester) async {
      for (final path in [
        PersonalProxyStatus.pathUnavailable,
        PersonalProxyStatus.pathConnecting,
        PersonalProxyStatus.pathReconnecting,
      ]) {
        await pumpPath(tester, path, direct: true);
        expect(find.text('Sara'), findsOneWidget);
        expect(find.text(connecting), findsNothing);
        expect(find.text(reconnecting), findsNothing);
        expect(find.text(unavailable), findsNothing);
        await pumpPath(tester, path, reverse: true);
        expect(find.text(connecting), findsNothing);
        expect(find.text(reconnecting), findsNothing);
        expect(find.text(unavailable), findsNothing);
      }
    });

    testWidgets('is polled only while connected with a friend selected on '
        'their own', (tester) async {
      final on = _Status(null);
      await _pumpFriend(tester, sara, vpn: VPNStatus.connected, status: on);
      await tester.pump();
      expect(on.polls, 1);

      final off = _Status(null);
      await tester.pumpWidget(const SizedBox());
      await _pumpFriend(tester, sara, status: off);
      await tester.pump();
      expect(off.polls, 0);

      final group = _Status(null);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vpnProvider.overrideWithValue(VPNStatus.connected),
            personalProxyStatusProvider.overrideWith(() => group),
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
      expect(group.polls, 0, reason: 'the group shows no path');
    });
  });
}
