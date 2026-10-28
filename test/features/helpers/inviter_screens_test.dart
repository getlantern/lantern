import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// common.dart re-exports the generated route classes, which share the
// screens' names.
import 'package:lantern/core/common/common.dart'
    hide GetHelp, InviteShare, Setting;
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/helpers/approve_helper_sheet.dart';
import 'package:lantern/features/helpers/get_help.dart';
import 'package:lantern/features/helpers/invite_share.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/country_code_notifier.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/setting/setting.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';
import 'package:share_plus/share_plus.dart';

class _Helpers extends HelpersNotifier {
  _Helpers(this.initial);
  final HelpersState initial;
  final decisions = <(String, bool)>[];
  int refreshes = 0;

  @override
  HelpersState build() => initial;

  @override
  Future<void> refreshIfUsed() async => refreshes++;

  @override
  Future<HelperResult> decide(String inviteId, {required bool approve}) async {
    decisions.add((inviteId, approve));
    return HelperResult.parse('{"unlocked":true}');
  }

  int endAll = 0;
  final ended = <String>[];
  final created = <String>[];

  @override
  Future<HelperResult> endAllHelpers() async {
    endAll++;
    return HelperResult.parse('{}');
  }

  @override
  Future<HelperResult> endPairing(String pairingId) async {
    ended.add(pairingId);
    return HelperResult.parse('{}');
  }

  @override
  Future<HelperResult> createInvite(String name) async {
    created.add(name);
    return HelperResult.parse(
      '{"invite_id":"i9","link":"https://lantern.io/help/#SECRET"}',
    );
  }
}

class _Storage implements LocalStorageService {
  _Storage({this.used = false});
  final bool used;
  @override
  bool? getBool(String key) => key == HelpersNotifier.usedKey ? used : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Router extends AppRouter {
  final pushed = <PageRouteInfo>[];

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route);
    return null;
  }
}

class _Platform extends LanternPlatformService {
  final copied = <String>[];

  @override
  Future<void> copySensitiveText(String text) async => copied.add(text);
}

/// Pumps [child] as a route pushed over a home page, so the test can pop it.
/// The route has no transitions, so a pop unmounts [child] at once.
Future<void> _pumpPushed(
  WidgetTester tester,
  _Helpers fake,
  Widget child,
) async {
  await _pump(
    tester,
    fake,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(
          PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
        child: const Text('open'),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

const _oneHelper = HelpersState(
  view: HelpersView(
    unlocked: true,
    helpers: [HelperPairingView(pairingId: 'p1', name: 'Ali', online: true)],
  ),
);

Future<void> _pump(WidgetTester tester, _Helpers fake, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [helpersProvider.overrideWith(() => fake)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

const _claimed = HelperInviteView(
  id: 'i1',
  state: 'claimed',
  code: '2562',
  volunteerName: 'Ali',
);

void main() {
  testWidgets('the approve sheet shows the code and approves', (tester) async {
    final fake = _Helpers(const HelpersState());
    await _pump(tester, fake, const ApproveHelperSheet(invite: _claimed));
    expect(find.byKey(const Key('approve.code')), findsOneWidget);
    expect(find.text('2562'), findsOneWidget);
    await tester.tap(find.byKey(const Key('approve.yes')));
    await tester.pumpAndSettle();
    expect(fake.decisions, [('i1', true)]);
  });

  testWidgets('the approve sheet rejects', (tester) async {
    final fake = _Helpers(const HelpersState());
    await _pump(tester, fake, const ApproveHelperSheet(invite: _claimed));
    await tester.tap(find.byKey(const Key('approve.no')));
    await tester.pumpAndSettle();
    expect(fake.decisions, [('i1', false)]);
  });

  testWidgets('one helper: status shown and a second helper suggested', (
    tester,
  ) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(
          unlocked: true,
          helpers: [
            HelperPairingView(
              pairingId: 'p1',
              name: 'Ali',
              online: true,
              sinceUnix: 1700000000,
            ),
          ],
        ),
      ),
    );
    await _pump(tester, fake, const GetHelp());
    expect(find.text('Ali'), findsOneWidget);
    expect(find.byKey(const Key('helpers.online.0')), findsOneWidget);
    expect(find.byKey(const Key('helpers.nudge')), findsOneWidget);
    expect(
      fake.refreshes,
      1,
      reason: 'opening the screen refreshes, if helper invites were used',
    );
  });

  testWidgets('two helpers: no nudge; offline shown', (tester) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(
          unlocked: true,
          helpers: [
            HelperPairingView(pairingId: 'p1', name: 'Ali', online: true),
            HelperPairingView(pairingId: 'p2', name: 'Bo'),
          ],
        ),
      ),
    );
    await _pump(tester, fake, const GetHelp());
    expect(find.byKey(const Key('helpers.nudge')), findsNothing);
    expect(find.byKey(const Key('helpers.offline.1')), findsOneWidget);
  });

  testWidgets('a claimed invite is surfaced above the helpers', (tester) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(unlocked: true, invites: [_claimed]),
      ),
    );
    await _pump(tester, fake, const GetHelp());
    expect(find.byKey(const Key('helpers.claimed.i1')), findsOneWidget);
  });

  testWidgets('a keystore reset is shown until the user dismisses it', (
    tester,
  ) async {
    final fake = _Helpers(const HelpersState(keystoreReset: true));
    await _pump(tester, fake, const GetHelp());
    expect(find.byKey(const Key('helpers.keystore_reset')), findsOneWidget);
    expect(find.text('helper_error_keystore_reset'.i18n), findsOneWidget);
    await tester.tap(find.byKey(const Key('helpers.keystore_reset.dismiss')));
    await tester.pump();
    expect(find.byKey(const Key('helpers.keystore_reset')), findsNothing);
    expect(fake.state.keystoreReset, isFalse);
  });

  testWidgets('askHelperName returns the trimmed name', (tester) async {
    final fake = _Helpers(const HelpersState());
    String? got;
    await _pump(
      tester,
      fake,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              got = await askHelperName(context, initial: '', title: 't'),
          child: const Text('ask'),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Sara  ');
    await tester.tap(find.text('continue'.i18n));
    await tester.pumpAndSettle();
    expect(got, 'Sara');
  });

  testWidgets('askHelperName returns null when cancelled', (tester) async {
    final fake = _Helpers(const HelpersState());
    String? got = 'unset';
    await _pump(
      tester,
      fake,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              got = await askHelperName(context, initial: 'Sara', title: 't'),
          child: const Text('ask'),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cancel'.i18n));
    await tester.pumpAndSettle();
    expect(got, isNull);
  });

  testWidgets('the invite screen shows a pending invite as a QR code', (
    tester,
  ) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(
          unlocked: true,
          myName: 'Sara',
          invites: [
            HelperInviteView(
              id: 'i2',
              state: 'pending',
              link: 'https://lantern.io/help/#AAAA',
            ),
          ],
        ),
      ),
    );
    await _pump(tester, fake, const InviteShare(inviteId: 'i2'));
    expect(find.byKey(const Key('invite.qr')), findsOneWidget);
    expect(find.byKey(const Key('invite.share')), findsOneWidget);
  });

  test('the share text names this invite\'s inviter, else the last name', () {
    const view = HelpersView(unlocked: true, myName: 'Sara');
    const named = HelperInviteView(
      id: 'i1',
      state: 'pending',
      link: 'https://lantern.io/help/#AAAA',
      inviterName: 'S. from work',
    );
    const unnamed = HelperInviteView(
      id: 'i2',
      state: 'pending',
      link: 'https://lantern.io/help/#BBBB',
    );
    expect(
      inviteShareMessage(view, named),
      'invite_share_message'.i18n.fill([
        'S. from work',
        'https://lantern.io/help/#AAAA',
      ]),
    );
    expect(
      inviteShareMessage(view, unnamed),
      'invite_share_message'.i18n.fill([
        'Sara',
        'https://lantern.io/help/#BBBB',
      ]),
    );
  });

  testWidgets('Share anchors the share sheet on the button', (tester) async {
    final shared = <ShareParams>[];
    debugShareInvite = (p) async => shared.add(p);
    addTearDown(() => debugShareInvite = null);
    final fake = _Helpers(
      HelpersState(
        view: HelpersView(
          unlocked: true,
          invites: [
            HelperInviteView(
              id: 'i2',
              state: 'pending',
              link: 'https://lantern.io/help/#SECRET',
              expiresUnix: _now() + 3600,
            ),
          ],
        ),
      ),
    );
    await _pump(tester, fake, const InviteShare(inviteId: 'i2'));
    await tester.tap(find.byKey(const Key('invite.share')));
    await tester.pump();
    final origin = shared.single.sharePositionOrigin;
    expect(origin, isNotNull);
    expect(origin!.isEmpty, isFalse);
    expect(origin, tester.getRect(find.byKey(const Key('invite.share'))));
    expect(
      shared.single.text,
      inviteShareMessage(fake.state.view, fake.state.view.invites.single),
    );
  });

  testWidgets('the invite screen says when the invite is gone', (tester) async {
    final fake = _Helpers(const HelpersState());
    await _pump(tester, fake, const InviteShare(inviteId: 'nope'));
    expect(find.byKey(const Key('invite.gone')), findsOneWidget);
  });

  group('with sl', () {
    setUp(() async => sl.reset());
    tearDown(() async {
      debugCopyAsAndroid = null;
      await sl.reset();
    });

    testWidgets('a pending invite opens InviteShare by its ID only', (
      tester,
    ) async {
      final router = _Router();
      sl.registerSingleton<AppRouter>(router);
      final fake = _Helpers(
        HelpersState(
          view: HelpersView(
            unlocked: true,
            invites: [
              HelperInviteView(
                id: 'i2',
                state: 'pending',
                link: 'https://lantern.io/help/#SECRET',
                expiresUnix: _now() + 3600,
              ),
            ],
          ),
        ),
      );
      await _pump(tester, fake, const GetHelp());
      await tester.tap(find.text('invite_waiting'.i18n));
      await tester.pump();
      expect(router.pushed, hasLength(1));
      final route = router.pushed.single;
      expect(route.routeName, 'InviteShare');
      expect((route.args as InviteShareArgs).inviteId, 'i2');
      expect(route.rawPathParams, isEmpty);
      expect(route.rawQueryParams, isEmpty);
      expect('${route.args}', isNot(contains('SECRET')));
    });

    testWidgets('inviting asks for a name, then opens the new invite by ID', (
      tester,
    ) async {
      final router = _Router();
      sl.registerSingleton<AppRouter>(router);
      final fake = _Helpers(const HelpersState());
      await _pump(tester, fake, const GetHelp());
      await tester.tap(find.byKey(const Key('helpers.invite')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Sara');
      await tester.tap(find.text('continue'.i18n));
      await tester.pumpAndSettle();
      expect(fake.created, ['Sara']);
      expect((router.pushed.single.args as InviteShareArgs).inviteId, 'i9');
    });

    testWidgets('Copy link goes through copySensitiveText', (tester) async {
      final platform = _Platform();
      sl.registerSingleton<LanternPlatformService>(platform);
      debugCopyAsAndroid = true;
      const link = 'https://lantern.io/help/#SECRET';
      final fake = _Helpers(
        const HelpersState(
          view: HelpersView(
            unlocked: true,
            invites: [HelperInviteView(id: 'i2', state: 'pending', link: link)],
          ),
        ),
      );
      await _pump(tester, fake, const InviteShare(inviteId: 'i2'));
      await tester.tap(find.byKey(const Key('invite.copy')));
      await tester.pump();
      expect(platform.copied, [link]);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('the Settings tile follows helperInvitesAvailableProvider', (
      tester,
    ) async {
      Future<void> pumpSetting(bool available) async {
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              helperInvitesAvailableProvider.overrideWithValue(available),
              isUserProProvider.overrideWithValue(true),
              isUserExpiredProvider.overrideWithValue(false),
              userEmailProvider.overrideWithValue(''),
              appSettingProvider.overrideWithValue(const AppSetting()),
              countryCodeProvider.overrideWithValue('US'),
              featureFlagProvider.overrideWithValue(const {}),
              homeProvider.overrideWith(_Home.new),
            ],
            child: ScreenUtilInit(
              designSize: const Size(393, 852),
              child: MaterialApp(
                theme: AppTheme.appTheme(),
                home: const Setting(),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      sl.registerSingleton<LocalStorageService>(_Storage());
      await pumpSetting(false);
      expect(find.byKey(const Key('setting.get_help_tile')), findsNothing);
      await pumpSetting(true);
      expect(find.byKey(const Key('setting.get_help_tile')), findsOneWidget);
      // Flag off on a device that used helper invites, before any view has
      // loaded: still offered, so its helpers can be managed.
      sl.unregister<LocalStorageService>();
      sl.registerSingleton<LocalStorageService>(_Storage(used: true));
      await pumpSetting(false);
      expect(find.byKey(const Key('setting.get_help_tile')), findsOneWidget);
    });
  });

  testWidgets('remove all still happens when the screen closes at once', (
    tester,
  ) async {
    final fake = _Helpers(_oneHelper);
    await _pumpPushed(tester, fake, const GetHelp());
    await tester.tap(find.text('helpers_remove_all'.i18n));
    await tester.pumpAndSettle();
    await tester.tap(find.text('remove'.i18n));
    await tester.pump();
    // Leave GetHelp inside AppDialog's 400 ms callback delay.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    expect(find.byType(GetHelp), findsNothing);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fake.endAll, 1);
  });

  testWidgets('removing a helper ends that pairing', (tester) async {
    final fake = _Helpers(_oneHelper);
    await _pump(tester, fake, const GetHelp());
    await tester.tap(find.byIcon(Icons.person_remove_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('remove'.i18n));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fake.ended, ['p1']);
  });

  testWidgets('an empty name keeps the dialog open and says why', (
    tester,
  ) async {
    final fake = _Helpers(const HelpersState());
    String? got = 'unset';
    await _pump(
      tester,
      fake,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              got = await askHelperName(context, initial: '', title: 't'),
          child: const Text('ask'),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('continue'.i18n));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const Key('helpers.name.error')), findsOneWidget);
    expect(got, 'unset');
    await tester.enterText(find.byType(TextFormField), 'Sara');
    await tester.pump();
    expect(find.byKey(const Key('helpers.name.error')), findsNothing);
    await tester.tap(find.text('continue'.i18n));
    await tester.pumpAndSettle();
    expect(got, 'Sara');
  });

  testWidgets('expired invites are not listed and not shareable', (
    tester,
  ) async {
    final fake = _Helpers(
      HelpersState(
        view: HelpersView(
          unlocked: true,
          invites: [
            HelperInviteView(
              id: 'old',
              state: 'pending',
              link: 'https://lantern.io/help/#OLD',
              expiresUnix: _now() - 10,
            ),
          ],
        ),
      ),
    );
    await _pump(tester, fake, const GetHelp());
    expect(find.text('invite_waiting'.i18n), findsNothing);
    expect(find.byKey(const Key('helpers.empty')), findsOneWidget);

    await _pump(tester, fake, const InviteShare(inviteId: 'old'));
    expect(find.byKey(const Key('invite.gone')), findsOneWidget);
    expect(find.byKey(const Key('invite.qr')), findsNothing);
  });

  testWidgets('a claimed invite offers codes, never the link or QR', (
    tester,
  ) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(unlocked: true, invites: [_claimed]),
      ),
    );
    await _pump(tester, fake, const InviteShare(inviteId: 'i1'));
    expect(find.byKey(const Key('invite.compare')), findsOneWidget);
    expect(find.byKey(const Key('invite.qr')), findsNothing);
    expect(find.byKey(const Key('invite.share')), findsNothing);
    expect(find.byKey(const Key('invite.copy')), findsNothing);
  });

  testWidgets('approving from InviteShare goes back', (tester) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(unlocked: true, invites: [_claimed]),
      ),
    );
    await _pumpPushed(tester, fake, const InviteShare(inviteId: 'i1'));
    await tester.tap(find.byKey(const Key('invite.compare')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('approve.yes')));
    await tester.pumpAndSettle();
    expect(fake.decisions, [('i1', true)]);
    expect(find.byType(InviteShare), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('the code is read out digit by digit', (tester) async {
    final handle = tester.ensureSemantics();
    final fake = _Helpers(const HelpersState());
    await _pump(tester, fake, const ApproveHelperSheet(invite: _claimed));
    expect(find.bySemanticsLabel('2 5 6 2'), findsOneWidget);
    expect(find.bySemanticsLabel('2562'), findsNothing);
    handle.dispose();
  });
}

class _Home extends HomeNotifier {
  @override
  Future<UserResponseModel> build() => Completer<UserResponseModel>().future;
}
