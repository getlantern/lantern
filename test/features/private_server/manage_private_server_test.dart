import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide ManagePrivateServer;
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/private_server/manage_private_server.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/personal_proxy_status_notifier.dart';

class _Servers extends AvailableServersNotifier {
  @override
  Future<AvailableServers> build() async => AvailableServers(const []);
}

class _FailingServers extends AvailableServersNotifier {
  @override
  Future<AvailableServers> build() async => throw Exception('offline');
}

/// The real notifier follows the VPN, which these tests do not run.
class _Status extends PersonalProxyStatusNotifier {
  @override
  Map<String, PersonalProxyStatus>? build() => null;

  @override
  Future<void> poll() async {}
}

class _Helpers extends HelpersNotifier {
  int refreshes = 0;

  @override
  HelpersState build() => _withAli;

  @override
  Future<void> refreshIfUsed() async => refreshes++;
}

const _withAli = HelpersState(
  viewLoaded: true,
  view: HelpersView(
    unlocked: true,
    helpers: [HelperPairingView(pairingId: 'p1', name: 'Ali', online: true)],
  ),
);

/// A device with nothing to manage yet.
class _NoHelpers extends HelpersNotifier {
  @override
  HelpersState build() =>
      const HelpersState(viewLoaded: true, view: HelpersView(unlocked: true));

  @override
  Future<void> refreshIfUsed() async {}
}

Future<void> _pump(
  WidgetTester tester, {
  bool tab = true,
  HelpersNotifier Function()? helpers,
  bool serversFail = false,
}) async {
  // The tab is there in every build with helper invites, empty or not.
  HelpersNotifier.debugBuildEnabled = tab;
  addTearDown(() => HelpersNotifier.debugBuildEnabled = null);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        availableServersProvider.overrideWith(
          serversFail ? _FailingServers.new : _Servers.new,
        ),
        helpersProvider.overrideWith(helpers ?? _Helpers.new),
        personalProxyStatusProvider.overrideWith(_Status.new),
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
      await _pump(tester);
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
    await _pump(tester, helpers: () => helpers);
    expect(helpers.refreshes, 0, reason: 'My Servers is the tab shown');
    await tester.tap(find.byKey(const Key('manage.personal_proxies_tab')));
    await tester.pumpAndSettle();
    expect(helpers.refreshes, 1);
  });

  testWidgets('three tab labels each fit on one line in a narrow window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    final bar = tester.getRect(find.byType(TabBar));
    for (final label in [
      'my_servers'.i18n,
      'joined_servers'.i18n,
      'personal_proxies_tab'.i18n,
    ]) {
      final text = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        text.size.width,
        greaterThanOrEqualTo(text.getMaxIntrinsicWidth(double.infinity)),
        reason: '"$label" wraps',
      );
      final rect = tester.getRect(find.text(label));
      expect(
        rect.top >= bar.top && rect.bottom <= bar.bottom,
        isTrue,
        reason: '"$label" is cut off',
      );
    }
  });

  testWidgets('two tabs in a build without helper invites', (tester) async {
    await _pump(tester, tab: false);
    expect(find.byKey(const Key('manage.personal_proxies_tab')), findsNothing);
  });

  testWidgets('the Personal Proxies tab stays while there is nothing to '
      'manage, with its empty state', (tester) async {
    await _pump(tester, helpers: _NoHelpers.new);
    await tester.tap(find.byKey(const Key('manage.personal_proxies_tab')));
    await tester.pumpAndSettle();
    final empty = find.byKey(const Key('personal_proxies.empty'));
    expect(empty, findsOneWidget);
    for (final text in [
      'manage_empty_proxies_title'.i18n,
      'manage_empty_proxies_body'.i18n,
      'invite_personal_proxy'.i18n,
    ]) {
      expect(
        find.descendant(of: empty, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(find.byKey(const Key('personal_proxies.invite')), findsOneWidget);
    expect(find.text('invite_another'.i18n), findsNothing);
  });

  testWidgets('My server and Joined show their empty states with no servers', (
    tester,
  ) async {
    await _pump(tester);
    final mine = find.byKey(const Key('manage.my_server.empty'));
    expect(mine, findsOneWidget);
    for (final text in [
      'manage_empty_my_server_title'.i18n,
      'manage_empty_my_server_body'.i18n,
      'setup_a_private_server'.i18n,
    ]) {
      expect(
        find.descendant(of: mine, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(find.text('access_key_expiration'.i18n), findsNothing);
    await tester.tap(find.text('joined_servers'.i18n));
    await tester.pumpAndSettle();
    final joined = find.byKey(const Key('manage.joined.empty'));
    expect(joined, findsOneWidget);
    for (final text in [
      'manage_empty_joined_title'.i18n,
      'manage_empty_joined_body'.i18n,
      'join_a_private_server'.i18n,
    ]) {
      expect(
        find.descendant(of: joined, matching: find.text(text)),
        findsOneWidget,
      );
    }
  });

  testWidgets('personal proxies stay manageable when servers fail to load', (
    tester,
  ) async {
    await _pump(tester, serversFail: true);
    expect(find.textContaining('offline'), findsOneWidget);
    await tester.tap(find.byKey(const Key('manage.personal_proxies_tab')));
    await tester.pumpAndSettle();
    expect(find.text('Ali'), findsOneWidget);
  });
}
