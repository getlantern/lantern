import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// common.dart re-exports the generated route classes, which share the
// screens' names.
import 'package:lantern/core/common/common.dart' hide InviteShare, Setting;
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/features/helpers/approve_helper_dialog.dart';
import 'package:lantern/features/helpers/helper_approval_prompt.dart';
import 'package:lantern/features/helpers/invite_share.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/helping_friends.dart'
    show helperSinceLabel;
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/personal_proxies_tab.dart';
import 'package:lantern/features/helpers/personal_proxy_banner.dart';
import 'package:lantern/features/helpers/personal_proxy_invite.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/plans/provider/payment_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/country_code_notifier.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/setting/setting.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';
import 'package:lantern/features/vpn/provider/personal_proxy_status_notifier.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class _Helpers extends HelpersNotifier {
  _Helpers(this.initial);
  final HelpersState initial;
  final decisions = <(String, bool)>[];
  int refreshes = 0;

  @override
  HelpersState build() => initial;

  void emit(HelpersState next) => state = next;

  @override
  Future<void> refreshIfUsed() async => refreshes++;

  bool usedFlag = false;

  @override
  bool get used => usedFlag;

  /// What refresh() loads, as the engine's view would.
  HelpersState? onRefresh;
  HelperResult? refreshResult;
  int fullRefreshes = 0;

  @override
  Future<HelperResult> refresh() async {
    fullRefreshes++;
    if (refreshResult != null) return refreshResult!;
    if (onRefresh != null) state = onRefresh!;
    return HelperResult.parse('{"unlocked":true}');
  }

  HelperResult? decideResult;
  // When set, decide waits for it.
  Completer<void>? decideGate;

  @override
  Future<HelperResult> decide(String inviteId, {required bool approve}) async {
    decisions.add((inviteId, approve));
    await decideGate?.future;
    if (onDecide != null) state = onDecide!;
    return decideResult ?? HelperResult.parse('{"unlocked":true}');
  }

  /// The state a successful decide leaves, as the engine's view would.
  HelpersState? onDecide;

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

  final renamed = <(String, String)>[];
  final forgotten = <String>[];

  @override
  Future<HelperResult> renameHelper(String pairingId, String name) async {
    renamed.add((pairingId, name));
    return HelperResult.parse('{}');
  }

  @override
  Future<HelperResult> forgetInvite(String inviteId) async {
    forgotten.add(inviteId);
    return HelperResult.parse('{}');
  }

  final renamedInvites = <(String, String)>[];

  @override
  Future<HelperResult> renameInvite(String inviteId, String name) async {
    renamedInvites.add((inviteId, name));
    state = state.copyWith(
      view: HelpersView(
        unlocked: true,
        myName: name,
        invites: [
          for (final i in state.view.invites)
            i.id == inviteId
                ? HelperInviteView(
                    id: i.id,
                    state: i.state,
                    link: i.link,
                    expiresUnix: i.expiresUnix,
                    inviterName: name,
                  )
                : i,
        ],
      ),
    );
    return HelperResult.parse('{"unlocked":true}');
  }

  /// When set, a created invite joins the view, as the engine's would.
  bool addCreated = false;

  @override
  Future<HelperResult> createInvite(String name) async {
    created.add(name);
    if (addCreated) {
      state = state.copyWith(
        view: HelpersView(
          unlocked: true,
          myName: name,
          invites: [
            ...state.view.invites,
            HelperInviteView(
              id: 'i9',
              state: 'pending',
              link: 'https://lantern.io/help/#SECRET',
              inviterName: name,
            ),
          ],
        ),
      );
    }
    return HelperResult.parse(
      '{"invite_id":"i9","link":"https://lantern.io/help/#SECRET"}',
    );
  }
}

class _PromptHost extends HookConsumerWidget {
  const _PromptHost(this.routes, this.overlay);
  final UserMessageRouteObserver routes;
  final ValueListenable<bool> overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useHelperApprovalPrompt(
      context,
      ref,
      routes,
      overlayVisible: (_) => overlay.value,
    );
    return const Text('home');
  }
}

Future<UserMessageRouteObserver> _pumpPromptHost(
  WidgetTester tester,
  _Helpers fake, {
  ValueListenable<bool> overlay = const _Off(),
}) async {
  final routes = UserMessageRouteObserver();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [helpersProvider.overrideWith(() => fake)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          navigatorObservers: [routes],
          home: Scaffold(body: _PromptHost(routes, overlay)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return routes;
}

class _Off implements ValueListenable<bool> {
  const _Off();
  @override
  bool get value => false;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
}

/// Pushes [child] over the prompt host's page, as appRouter would. Pumps
/// past the transition rather than settling: InviteShare's wait spins.
Future<void> _pushOverHost(WidgetTester tester, Widget child) async {
  unawaited(
    Navigator.of(
      tester.element(find.text('home', skipOffstage: false)),
    ).push(MaterialPageRoute<void>(builder: (_) => Scaffold(body: child))),
  );
  await _pumpPast(tester);
}

Future<void> _pumpPast(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

HelpersState _withInvites(List<HelperInviteView> invites) => HelpersState(
  viewLoaded: true,
  view: HelpersView(unlocked: true, invites: invites),
);

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

/// The confirmation dialog's Remove, not the row's.
final _dialogRemove = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.text('remove'.i18n),
);

int _now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

const _oneHelper = HelpersState(
  view: HelpersView(
    unlocked: true,
    helpers: [HelperPairingView(pairingId: 'p1', name: 'Ali', online: true)],
  ),
);

class _Status extends PersonalProxyStatusNotifier {
  _Status(this.initial);
  final Map<String, PersonalProxyStatus>? initial;
  int polls = 0;
  @override
  Map<String, PersonalProxyStatus>? build() => initial;
  @override
  Future<void> poll() async => polls++;
}

late _Status _status;

Future<void> _pump(
  WidgetTester tester,
  _Helpers fake,
  Widget child, {
  Map<String, PersonalProxyStatus>? status,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        helpersProvider.overrideWith(() => fake),
        personalProxyStatusProvider.overrideWith(
          () => _status = _Status(status),
        ),
      ],
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

const _pendingI1 = HelperInviteView(
  id: 'i1',
  state: 'pending',
  link: 'https://lantern.io/help/#AAAA',
  inviterName: 'Sara',
);

const _claimed = HelperInviteView(
  id: 'i1',
  state: 'claimed',
  code: '2562',
  volunteerName: 'Ali',
);

final _approveYes = find.widgetWithText(
  PrimaryButton,
  'approve_codes_match'.i18n,
);
final _approveNo = find.widgetWithText(SecondaryButton, 'approve_reject'.i18n);
final _approvedConnect = find.widgetWithText(
  PrimaryButton,
  'approved_connect_now'.i18n,
);
final _approvedDone = find.widgetWithText(
  SecondaryButton,
  'help_friend_done'.i18n,
);

/// Opens the approval dialog for [_claimed]; completes with its result.
Future<Future<bool>> _openApproval(WidgetTester tester, _Helpers fake) async {
  final result = Completer<bool>();
  await _pump(
    tester,
    fake,
    Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () async => result.complete(
          await showApproveHelperDialog(context, ref, _claimed),
        ),
        child: const Text('approve'),
      ),
    ),
  );
  await tester.tap(find.text('approve'));
  await tester.pumpAndSettle();
  return result.future;
}

void main() {
  setUpAll(Localization.loadTranslations);

  testWidgets('the approval dialog names the friend, shows the code and '
      'approves', (tester) async {
    final fake = _Helpers(const HelpersState());
    final result = await _openApproval(tester, fake);
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.text('approve_title'.i18n.fill(['Ali'])), findsOneWidget);
    expect(find.text('approve_body'.i18n.fill(['Ali'])), findsOneWidget);
    expect(find.byKey(const Key('approve.code')), findsOneWidget);
    expect(find.text('2562'), findsOneWidget);
    // The pin pad, as in the design; the check belongs to the success
    // dialog. On the surface grey, not white.
    expect(
      find.descendant(
        of: dialog,
        matching: find.byWidgetPredicate(
          (w) => w is AppImage && w.path == AppImagePaths.keypad,
        ),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    expect(
      tester.widget<AlertDialog>(dialog).backgroundColor,
      tester.element(dialog).bgSurface,
    );
    final code = tester.widget<Text>(find.byKey(const Key('approve.code')));
    expect(
      code.style?.fontSize,
      Theme.of(tester.element(dialog)).textTheme.displayMedium?.fontSize,
    );
    await tester.tap(_approveYes);
    await tester.pumpAndSettle();
    expect(fake.decisions, [('i1', true)]);
    expect(find.text('approve_title'.i18n.fill(['Ali'])), findsNothing);
    // The success dialog follows, with the check; Done closes it.
    expect(find.text('approved_title'.i18n.fill(['Ali'])), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    await tester.tap(_approvedDone);
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(await result, isTrue);
  });

  testWidgets('after approving: "[Name] is now your Personal Proxy", where to '
      'pick them, Connect Now and Done', (tester) async {
    final connects = <String?>[];
    debugConnectPersonalProxy = (tag) async => connects.add(tag);
    addTearDown(() => debugConnectPersonalProxy = null);
    final fake = _Helpers(const HelpersState())
      ..onDecide = const HelpersState(
        view: HelpersView(
          unlocked: true,
          helpers: [
            HelperPairingView(
              pairingId: 'p1',
              name: 'Ali',
              outboundTag: 'helper-p1',
            ),
          ],
        ),
      );
    final result = await _openApproval(tester, fake);
    await tester.tap(_approveYes);
    await tester.pumpAndSettle();
    expect(find.text('approved_title'.i18n.fill(['Ali'])), findsOneWidget);
    expect(find.text('approved_body'.i18n.fill(['Ali'])), findsOneWidget);
    expect(_approvedConnect, findsOneWidget);
    expect(_approvedDone, findsOneWidget);
    await tester.tap(_approvedConnect);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    // The new friend alone, by their outbound tag.
    expect(connects, ['helper-p1']);
    expect(await result, isTrue);
  });

  testWidgets('Connect Now uses the personal proxies group when the new '
      'friend cannot be told', (tester) async {
    final connects = <String?>[];
    debugConnectPersonalProxy = (tag) async => connects.add(tag);
    addTearDown(() => debugConnectPersonalProxy = null);
    final fake = _Helpers(const HelpersState());
    await _openApproval(tester, fake);
    await tester.tap(_approveYes);
    await tester.pumpAndSettle();
    await tester.tap(_approvedConnect);
    await tester.pumpAndSettle();
    expect(connects, [null]);
  });

  testWidgets('the approval returns only once Connect Now has finished '
      'connecting, so its caller stays while the connection runs', (
    tester,
  ) async {
    final connecting = Completer<void>();
    debugConnectPersonalProxy = (tag) => connecting.future;
    addTearDown(() => debugConnectPersonalProxy = null);
    final fake = _Helpers(const HelpersState());
    final result = await _openApproval(tester, fake);
    var returned = false;
    unawaited(result.then((_) => returned = true));
    await tester.tap(_approveYes);
    await tester.pumpAndSettle();
    await tester.tap(_approvedConnect);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(returned, isFalse);
    connecting.complete();
    await tester.pumpAndSettle();
    expect(returned, isTrue);
  });

  testWidgets('Done after approving connects nothing', (tester) async {
    final connects = <String?>[];
    debugConnectPersonalProxy = (tag) async => connects.add(tag);
    addTearDown(() => debugConnectPersonalProxy = null);
    final fake = _Helpers(const HelpersState());
    await _openApproval(tester, fake);
    await tester.tap(_approveYes);
    await tester.pumpAndSettle();
    await tester.tap(_approvedDone);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(connects, isEmpty);
  });

  testWidgets('rejecting decides with reject, which burns the invite', (
    tester,
  ) async {
    final fake = _Helpers(const HelpersState());
    final result = await _openApproval(tester, fake);
    await tester.tap(_approveNo);
    await tester.pumpAndSettle();
    expect(fake.decisions, [('i1', false)]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await result, isTrue);
  });

  testWidgets('the approval dialog does not close on a tap outside', (
    tester,
  ) async {
    final fake = _Helpers(const HelpersState());
    await _openApproval(tester, fake);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(fake.decisions, isEmpty);
  });

  testWidgets('an approval decided elsewhere closes the dialog and re-reads', (
    tester,
  ) async {
    final fake = _Helpers(const HelpersState())
      ..decideResult = HelperResult.failure('no_pending_claim');
    final result = await _openApproval(tester, fake);
    await tester.tap(_approveYes);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(fake.fullRefreshes, 1);
    expect(await result, isFalse);
  });

  testWidgets('the approval dialog scrolls to its buttons on a small phone '
      'with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final fake = _Helpers(const HelpersState());
    await _openApproval(tester, fake);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      _approveNo,
      100,
      scrollable: find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(_approveNo);
    await tester.pumpAndSettle();
    expect(fake.decisions, [('i1', false)]);
  });

  testWidgets('Back during a decision leaves the screen under the dialog', (
    tester,
  ) async {
    final fake = _Helpers(const HelpersState())..decideGate = Completer();
    final result = await _openApproval(tester, fake);
    await tester.tap(_approveYes);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    fake.decideGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('approve'), findsOneWidget);
    expect(await result, isTrue);
  });

  testWidgets('the approval dialog says to compare the code away from the '
      'link', (tester) async {
    final fake = _Helpers(const HelpersState());
    await _openApproval(tester, fake);
    final body = 'approve_body'.i18n.fill(['Ali']);
    expect(find.text(body), findsOneWidget);
    expect(body, contains('different app from the one you sent the link in'));
  });

  testWidgets('a decision that lands after Back does not close a newer '
      'dialog', (tester) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(unlocked: true, invites: [_claimed]),
      ),
    )..decideGate = Completer();
    await _pump(
      tester,
      fake,
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => showApproveHelperDialog(context, ref, _claimed),
          child: const Text('approve'),
        ),
      ),
    );
    await tester.tap(find.text('approve'));
    await tester.pumpAndSettle();
    await tester.tap(_approveYes);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    // Open it again while the first decision is still in flight.
    await tester.tap(find.text('approve'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    fake.decideGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('one helper: status shown', (tester) async {
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
    await _pump(tester, fake, const PersonalProxiesTab());
    expect(find.text('Ali'), findsOneWidget);
    expect(find.byKey(const Key('helpers.online.0')), findsOneWidget);
    expect(
      find.text('${'helper_online'.i18n} · ${helperSinceLabel(1700000000)}'),
      findsOneWidget,
    );
    // Trash and pencil icon buttons, in that order, in the friend's own card.
    final trash = find.byKey(const Key('personal_proxies.remove.p1'));
    final pencil = find.byKey(const Key('personal_proxies.rename.p1'));
    expect(
      find.descendant(of: trash, matching: find.byIcon(Icons.delete_outline)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pencil, matching: find.byIcon(Icons.edit_outlined)),
      findsOneWidget,
    );
    expect(tester.getCenter(trash).dx, lessThan(tester.getCenter(pencil).dx));
    expect(
      find.ancestor(of: trash, matching: find.byType(AppCard)),
      findsOneWidget,
    );
    expect(find.byType(Flag), findsNothing);
    expect(find.byKey(const Key('helpers.nudge')), findsOneWidget);
    expect(find.text('helpers_nudge_second'.i18n), findsOneWidget);
    expect(
      fake.refreshes,
      1,
      reason: 'showing the tab refreshes, if helper invites were used',
    );
  });

  testWidgets('two helpers: offline shown', (tester) async {
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
    await _pump(tester, fake, const PersonalProxiesTab());
    expect(find.byKey(const Key('helpers.offline.1')), findsOneWidget);
    expect(find.text('helper_offline'.i18n), findsOneWidget);
    // Each friend has a card of their own.
    expect(
      find.ancestor(
        of: find.byKey(const Key('personal_proxies.remove.p2')),
        matching: find.byType(AppCard),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('helpers.nudge')), findsNothing);
  });

  testWidgets('a helper offline by presence but with a live reverse route '
      'is shown online', (tester) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(
          unlocked: true,
          helpers: [
            HelperPairingView(
              pairingId: 'p1',
              name: 'Ali',
              outboundTag: 'helper-0123456789ab',
            ),
            HelperPairingView(
              pairingId: 'p2',
              name: 'Bo',
              outboundTag: 'helper-ba9876543210',
            ),
          ],
        ),
      ),
    );
    await _pump(
      tester,
      fake,
      const PersonalProxiesTab(),
      status: const {
        'helper-0123456789ab': PersonalProxyStatus(reverse: true),
        'helper-ba9876543210': PersonalProxyStatus(direct: true),
      },
    );
    expect(find.byKey(const Key('helpers.online.0')), findsOneWidget);
    expect(find.byKey(const Key('helpers.offline.1')), findsOneWidget);
  });

  testWidgets("radiance's friend status is read on opening and on its "
      'interval, only while the tab shows friends and the app is resumed', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(
          unlocked: true,
          helpers: [HelperPairingView(pairingId: 'p1', name: 'Ali')],
        ),
      ),
    );
    await _pump(tester, fake, const PersonalProxiesTab());
    expect(_status.polls, 1, reason: 'read once on opening');
    await tester.pump(personalProxyStatusInterval);
    expect(_status.polls, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(personalProxyStatusInterval * 3);
    expect(_status.polls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(personalProxyStatusInterval);
    expect(_status.polls, 3);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(personalProxyStatusInterval * 3);
    expect(_status.polls, 3, reason: 'closing the tab stops the poll');
  });

  testWidgets('no status poll without helpers', (tester) async {
    final fake = _Helpers(
      const HelpersState(view: HelpersView(unlocked: true)),
    );
    await _pump(tester, fake, const PersonalProxiesTab());
    await tester.pump(personalProxyStatusInterval * 3);
    expect(_status.polls, 0);
  });

  testWidgets('a claimed invite is surfaced above the helpers', (tester) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(unlocked: true, invites: [_claimed]),
      ),
    );
    await _pump(tester, fake, const PersonalProxiesTab());
    expect(find.byKey(const Key('helpers.claimed.i1')), findsOneWidget);
  });

  testWidgets('a keystore reset is shown until the user dismisses it', (
    tester,
  ) async {
    final fake = _Helpers(const HelpersState(keystoreReset: true));
    await _pump(tester, fake, const PersonalProxiesTab());
    expect(find.byKey(const Key('helping.keystore_reset')), findsOneWidget);
    expect(find.text('helper_error_keystore_reset'.i18n), findsOneWidget);
    await tester.tap(find.byKey(const Key('helping.keystore_reset.dismiss')));
    await tester.pump();
    expect(find.byKey(const Key('helping.keystore_reset')), findsNothing);
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

  testWidgets('the invite screen: the name above the link, Show QR code '
      'beside the expiry, the waiting line under Share, and no QR code', (
    tester,
  ) async {
    // Tall enough to build the whole list in the test font.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
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
              inviterName: 'Sara',
            ),
          ],
        ),
      ),
    );
    await _pump(tester, fake, const InviteShare(inviteId: 'i2'));
    expect(find.byKey(const Key('invite.qr')), findsNothing);
    expect(find.text('invite_personal_proxy'.i18n), findsOneWidget);
    final card = find.byKey(const Key('invite.card'));
    for (final text in [
      'invite_share_title'.i18n,
      'invite_share_steps'.i18n,
      'helpers_your_name_label'.i18n,
      'invite_link_label'.i18n,
      '${'invite_link_expiry'.i18n} · ',
      'invite_show_qr'.i18n,
      'invite_waiting'.i18n,
      'https://lantern.io/help/#AAAA',
      'Sara',
    ]) {
      expect(
        find.descendant(of: card, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    final name = find.byKey(const Key('invite.name'));
    final link = find.byKey(const Key('invite.link'));
    final share = find.byKey(const Key('invite.share'));
    final waiting = find.byKey(const Key('invite.waiting'));
    expect(tester.getTopLeft(name).dy, lessThan(tester.getTopLeft(link).dy));
    expect(
      tester.getTopLeft(waiting).dy,
      greaterThan(tester.getBottomLeft(share).dy),
    );
    expect(
      find.descendant(of: waiting, matching: find.byIcon(Icons.sync)),
      findsOneWidget,
    );
    for (final key in ['invite.copy', 'invite.show_qr']) {
      expect(
        find.descendant(of: card, matching: find.byKey(Key(key))),
        findsOneWidget,
      );
    }
    final warning = find.byKey(const Key('invite.trust_warning'));
    expect(
      find.descendant(
        of: warning,
        matching: find.text('invite_trust_warning'.i18n),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(warning).dy,
      greaterThan(tester.getBottomLeft(card).dy),
    );
    expect(fake.created, isEmpty);
    expect(fake.renamedInvites, isEmpty);
  });

  testWidgets('Show QR code opens the code in a dialog, which Done closes', (
    tester,
  ) async {
    final fake = _Helpers(_withInvites(const [_pendingI1]));
    await _pump(tester, fake, const InviteShare(inviteId: 'i1'));
    await tester.tap(find.byKey(const Key('invite.show_qr')));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    for (final text in ['invite_qr_title'.i18n, 'invite_qr_hint'.i18n]) {
      expect(
        find.descendant(of: dialog, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(
      tester.getSize(find.byKey(const Key('invite.qr'))),
      const Size(160, 160),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('invite.qr')),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is QrPainter,
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<AlertDialog>(dialog).backgroundColor,
      tester.element(dialog).bgSurface,
    );
    await tester.tap(find.text('done'.i18n));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(find.byKey(const Key('invite.qr')), findsNothing);
  });

  testWidgets('the copy icon shows the check after copying, then the copy '
      'icon again', (tester) async {
    debugCopyAsAndroid = false;
    addTearDown(() => debugCopyAsAndroid = null);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final fake = _Helpers(_withInvites(const [_pendingI1]));
    await _pump(tester, fake, const InviteShare(inviteId: 'i1'));
    CrossFadeState fade() => tester
        .widget<AnimatedCrossFade>(
          find.descendant(
            of: find.byKey(const Key('invite.copy')),
            matching: find.byType(AnimatedCrossFade),
          ),
        )
        .crossFadeState;
    expect(fade(), CrossFadeState.showFirst);
    await tester.tap(find.byKey(const Key('invite.copy')));
    await tester.pump();
    expect(fade(), CrossFadeState.showSecond);
    final check = tester.widget<Icon>(find.byKey(const Key('invite.copied')));
    expect(check.icon, Icons.check_circle);
    expect(
      check.color,
      tester.element(find.byType(InviteShare)).statusSuccessBg,
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(fade(), CrossFadeState.showFirst);
  });

  testWidgets('a new invite is made at once with the name known already', (
    tester,
  ) async {
    final fake = _Helpers(
      const HelpersState(view: HelpersView(unlocked: true, myName: 'Sara')),
    )..addCreated = true;
    await _pump(tester, fake, const InviteShare());
    await tester.pump();
    expect(fake.created, ['Sara']);
    expect(find.text('https://lantern.io/help/#SECRET'), findsOneWidget);
    expect(find.byKey(const Key('invite.waiting')), findsOneWidget);
  });

  testWidgets('without a name, Share asks for one on the screen; the name '
      'typed makes the invite, capitalized', (tester) async {
    final shared = <ShareParams>[];
    debugShareInvite = (p) async => shared.add(p);
    addTearDown(() => debugShareInvite = null);
    final fake = _Helpers(const HelpersState(view: HelpersView(unlocked: true)))
      ..addCreated = true;
    await _pump(tester, fake, const InviteShare());
    await tester.pump();
    expect(fake.created, isEmpty);
    expect(find.byType(AlertDialog), findsNothing, reason: 'no name dialog');
    expect(find.text('invite_link_hint'.i18n), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite.share')));
    await tester.pump();
    expect(find.byKey(const Key('invite.name.error')), findsOneWidget);
    expect(fake.created, isEmpty);
    expect(shared, isEmpty);

    await tester.enterText(find.byKey(const Key('invite.name')), 'sara');
    await tester.pump();
    expect(find.byKey(const Key('invite.name.error')), findsNothing);
    expect(find.text('Sara'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite.share')));
    await tester.pump();
    await tester.pump();
    expect(fake.created, ['Sara']);
    expect(shared.single.text, contains('https://lantern.io/help/#SECRET'));
  });

  testWidgets('a name changed after the link was made is saved to the invite '
      'before it is shared', (tester) async {
    final shared = <ShareParams>[];
    debugShareInvite = (p) async => shared.add(p);
    addTearDown(() => debugShareInvite = null);
    final fake = _Helpers(_withInvites(const [_pendingI1]));
    await _pump(tester, fake, const InviteShare(inviteId: 'i1'));
    await tester.enterText(find.byKey(const Key('invite.name')), 'Sara K');
    await tester.tap(find.byKey(const Key('invite.share')));
    await tester.pump();
    await tester.pump();
    expect(fake.renamedInvites, [('i1', 'Sara K')]);
    expect(fake.created, isEmpty);
    expect(
      shared.single.text,
      'invite_share_message'.i18n.fill([
        'Sara K',
        'https://lantern.io/help/#AAAA',
      ]),
    );
  });

  testWidgets('tapping the link field copies the link', (tester) async {
    debugCopyAsAndroid = false;
    addTearDown(() => debugCopyAsAndroid = null);
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(unlocked: true, invites: [_pendingI1]),
      ),
    );
    await _pump(tester, fake, const InviteShare(inviteId: 'i1'));
    await tester.tap(find.byKey(const Key('invite.link')));
    await tester.pump();
    expect(copied, ['https://lantern.io/help/#AAAA']);
    // Past the check icon's time.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the invite link has no selection menu to copy it around '
      'copySensitiveText', (tester) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(unlocked: true, invites: [_pendingI1]),
      ),
    );
    await _pump(tester, fake, const InviteShare(inviteId: 'i1'));
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('invite.link')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.enableInteractiveSelection, isFalse);
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
              inviterName: 'Sara',
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

  testWidgets('a claimed invite offers Compare codes in place of Share, which '
      'reopens the approval dialog', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final fake = _Helpers(_withInvites(const [_claimed]));
    await _pump(tester, fake, const InviteShare(inviteId: 'i1'));
    expect(find.byKey(const Key('invite.share')), findsNothing);
    expect(find.byKey(const Key('invite.waiting')), findsNothing);
    await tester.tap(find.byKey(const Key('invite.compare')));
    await tester.pumpAndSettle();
    expect(_approveYes, findsOneWidget);
    expect(find.text('2562'), findsOneWidget);
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
      await _pump(tester, fake, const PersonalProxiesTab());
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

    testWidgets('inviting opens the invite screen, with no name dialog '
        'before it', (tester) async {
      final router = _Router();
      sl.registerSingleton<AppRouter>(router);
      final fake = _Helpers(const HelpersState());
      await _pump(tester, fake, const PersonalProxiesTab());
      await tester.tap(find.byKey(const Key('personal_proxies.invite')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.created, isEmpty);
      expect(router.pushed.single.routeName, 'InviteShare');
      expect((router.pushed.single.args as InviteShareArgs).inviteId, isNull);
    });

    testWidgets('startPersonalProxyInvite opens the invite screen', (
      tester,
    ) async {
      final router = _Router();
      sl.registerSingleton<AppRouter>(router);
      final fake = _Helpers(const HelpersState());
      await _pump(
        tester,
        fake,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => startPersonalProxyInvite(context, ref),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.created, isEmpty);
      expect((router.pushed.single.args as InviteShareArgs).inviteId, isNull);
    });

    Future<void> tapStart(WidgetTester tester, _Helpers fake) async {
      await _pump(
        tester,
        fake,
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => startPersonalProxyInvite(context, ref),
            child: const Text('go'),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    const pendingInvite = HelperInviteView(id: 'i2', state: 'pending');

    testWidgets('startPersonalProxyInvite opens the approval of an invite '
        'awaiting it instead of creating one', (tester) async {
      final router = _Router();
      sl.registerSingleton<AppRouter>(router);
      final fake = _Helpers(
        const HelpersState(
          viewLoaded: true,
          view: HelpersView(unlocked: true, invites: [pendingInvite, _claimed]),
        ),
      );
      await tapStart(tester, fake);
      expect(find.byType(TextFormField), findsNothing, reason: 'no name asked');
      expect(fake.created, isEmpty);
      expect(router.pushed, isEmpty);
      expect(find.text('approve_title'.i18n.fill(['Ali'])), findsOneWidget);
      expect(fake.approvalPrompted('i1'), isTrue);
    });

    testWidgets('an invite no one has opened does not stop another', (
      tester,
    ) async {
      final router = _Router();
      sl.registerSingleton<AppRouter>(router);
      final fake = _Helpers(
        const HelpersState(
          viewLoaded: true,
          view: HelpersView(unlocked: true, invites: [pendingInvite]),
        ),
      );
      await tapStart(tester, fake);
      expect((router.pushed.single.args as InviteShareArgs).inviteId, isNull);
    });

    testWidgets('a used device loads its view before deciding', (tester) async {
      final router = _Router();
      sl.registerSingleton<AppRouter>(router);
      final fake = _Helpers(const HelpersState())
        ..usedFlag = true
        ..onRefresh = const HelpersState(
          viewLoaded: true,
          view: HelpersView(unlocked: true, invites: [_claimed]),
        );
      await tapStart(tester, fake);
      expect(fake.fullRefreshes, 1);
      expect(fake.created, isEmpty);
      expect(router.pushed, isEmpty);
      expect(find.byKey(const Key('approve.code')), findsOneWidget);
    });

    testWidgets('a used device whose view fails to load creates no invite', (
      tester,
    ) async {
      final router = _Router();
      sl.registerSingleton<AppRouter>(router);
      final fake = _Helpers(const HelpersState())
        ..usedFlag = true
        ..refreshResult = HelperResult.failure('unavailable');
      await tapStart(tester, fake);
      expect(fake.fullRefreshes, 1);
      expect(find.byType(TextFormField), findsNothing, reason: 'no name asked');
      expect(fake.created, isEmpty);
      expect(router.pushed, isEmpty);
      expect(find.text(helperErrorText('unavailable')), findsOneWidget);
    });

    testWidgets('Invite another in the Manage tab creates an invite while '
        'one awaits approval', (tester) async {
      final router = _Router();
      sl.registerSingleton<AppRouter>(router);
      final fake = _Helpers(
        const HelpersState(
          viewLoaded: true,
          view: HelpersView(unlocked: true, invites: [_claimed]),
        ),
      );
      await _pump(tester, fake, const PersonalProxiesTab());
      await tester.tap(find.byKey(const Key('personal_proxies.invite')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('approve.code')), findsNothing);
      expect((router.pushed.single.args as InviteShareArgs).inviteId, isNull);
    });

    for (final small in [false, true]) {
      testWidgets('the ${small ? 'compact ' : ''}banner says a friend is '
          'waiting and opens their approval', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = small
            ? const Size(393, 560)
            : const Size(393, 852);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final router = _Router();
        sl.registerSingleton<AppRouter>(router);
        final fake = _Helpers(
          const HelpersState(
            viewLoaded: true,
            view: HelpersView(unlocked: true, invites: [_claimed]),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              helpersProvider.overrideWith(() => fake),
              personalProxyBannerVisibleProvider.overrideWithValue(true),
            ],
            child: ScreenUtilInit(
              designSize: tester.view.physicalSize,
              child: MaterialApp(
                theme: AppTheme.appTheme(),
                home: const Scaffold(body: PersonalProxyBanner()),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text('personal_proxy_banner_waiting_title'.i18n),
          findsOneWidget,
        );
        expect(find.text('personal_proxy_banner_title'.i18n), findsNothing);
        expect(
          find.text('personal_proxy_banner_waiting_body'.i18n),
          small ? findsNothing : findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('vpn.personal_proxy_banner')));
        await tester.pumpAndSettle();
        expect(fake.created, isEmpty);
        expect(router.pushed, isEmpty);
        expect(find.byKey(const Key('approve.code')), findsOneWidget);
      });
    }

    testWidgets('Copy link goes through copySensitiveText', (tester) async {
      final platform = _Platform();
      sl.registerSingleton<LanternPlatformService>(platform);
      debugCopyAsAndroid = true;
      const link = 'https://lantern.io/help/#SECRET';
      final fake = _Helpers(
        const HelpersState(
          view: HelpersView(
            unlocked: true,
            invites: [
              HelperInviteView(
                id: 'i2',
                state: 'pending',
                link: link,
                inviterName: 'Sara',
              ),
            ],
          ),
        ),
      );
      await _pump(tester, fake, const InviteShare(inviteId: 'i2'));
      await tester.tap(find.byKey(const Key('invite.copy')));
      await tester.pump();
      expect(platform.copied, [link]);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Settings no longer offers "Get help from a friend"', (
      tester,
    ) async {
      sl.registerSingleton<LocalStorageService>(_Storage(used: true));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            helperInvitesAvailableProvider.overrideWithValue(true),
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
      expect(find.byKey(const Key('setting.get_help_tile')), findsNothing);
    });
  });

  group('the approval prompt', () {
    final approveCode = find.byKey(const Key('approve.code'));

    // Back, the only way to leave the dialog undecided.
    Future<void> dismissSheet(WidgetTester tester) async {
      Navigator.of(tester.element(approveCode)).pop();
      await tester.pumpAndSettle();
    }

    testWidgets('opens the dialog once per claim', (tester) async {
      final fake = _Helpers(_withInvites(const []));
      await _pumpPromptHost(tester, fake);
      expect(approveCode, findsNothing);

      fake.emit(_withInvites(const [_claimed]));
      await tester.pumpAndSettle();
      expect(approveCode, findsOneWidget);
      expect(find.text('2562'), findsOneWidget);
      await dismissSheet(tester);
      expect(approveCode, findsNothing);

      // The poll brings the same claim again: no second prompt.
      fake.emit(
        _withInvites(const [
          _claimed,
          HelperInviteView(id: 'i2', state: 'pending'),
        ]),
      );
      await tester.pumpAndSettle();
      expect(approveCode, findsNothing);

      // A new claim prompts.
      fake.emit(
        _withInvites(const [
          _claimed,
          HelperInviteView(id: 'i3', state: 'claimed', code: '7181'),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('7181'), findsOneWidget);
      expect(find.text('2562'), findsNothing);
    });

    testWidgets('waits for an open dialog to close', (tester) async {
      final fake = _Helpers(_withInvites(const []));
      await _pumpPromptHost(tester, fake);
      unawaited(
        showDialog<void>(
          context: tester.element(find.text('home')),
          builder: (_) => const AlertDialog(content: Text('other')),
        ),
      );
      await tester.pumpAndSettle();
      fake.emit(_withInvites(const [_claimed]));
      await tester.pumpAndSettle();
      expect(approveCode, findsNothing);

      Navigator.of(tester.element(find.text('other'))).pop();
      await tester.pumpAndSettle();
      expect(approveCode, findsOneWidget);
    });

    testWidgets('the friend opening the link goes straight to the approval '
        'dialog over the invite screen, with no screen between', (
      tester,
    ) async {
      final fake = _Helpers(_withInvites(const [_pendingI1]));
      await _pumpPromptHost(tester, fake);
      await _pushOverHost(tester, const InviteShare(inviteId: 'i1'));
      fake.emit(_withInvites(const [_claimed]));
      await _pumpPast(tester);
      expect(approveCode, findsOneWidget);
      expect(find.text('approve_title'.i18n.fill(['Ali'])), findsOneWidget);
      expect(fake.approvalPrompted('i1'), isTrue);
    });

    testWidgets('approving from the prompt over the invite screen closes '
        'that screen once the success dialog is done', (tester) async {
      final fake = _Helpers(_withInvites(const [_pendingI1]))
        ..onDecide = _withInvites(const []);
      await _pumpPromptHost(tester, fake);
      await _pushOverHost(tester, const InviteShare(inviteId: 'i1'));
      fake.emit(_withInvites(const [_claimed]));
      await _pumpPast(tester);
      await tester.tap(_approveYes);
      await _pumpPast(tester);
      expect(fake.decisions, [('i1', true)]);
      expect(find.byType(InviteShare), findsOneWidget, reason: 'under it');
      await tester.tap(_approvedDone);
      await _pumpPast(tester);
      await _pumpPast(tester);
      expect(find.byType(InviteShare), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('Connect Now from an approval reopened by Compare codes keeps '
        'the invite screen until the connection finishes', (tester) async {
      final connecting = Completer<void>();
      debugConnectPersonalProxy = (tag) => connecting.future;
      addTearDown(() => debugConnectPersonalProxy = null);
      final fake = _Helpers(_withInvites(const [_pendingI1]))
        ..onDecide = _withInvites(const []);
      await _pumpPromptHost(tester, fake);
      await _pushOverHost(tester, const InviteShare(inviteId: 'i1'));
      // Prompted already and dismissed undecided.
      fake.markApprovalPrompted('i1');
      fake.emit(_withInvites(const [_claimed]));
      await _pumpPast(tester);
      expect(approveCode, findsNothing);
      await tester.tap(find.byKey(const Key('invite.compare')));
      await _pumpPast(tester);
      await tester.tap(_approveYes);
      await _pumpPast(tester);
      await tester.tap(_approvedConnect);
      await _pumpPast(tester);
      await _pumpPast(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(InviteShare), findsOneWidget, reason: 'connecting');
      connecting.complete();
      await _pumpPast(tester);
      await _pumpPast(tester);
      expect(find.byType(InviteShare), findsNothing);
    });

    testWidgets('opens over another screen that covers the invite screen', (
      tester,
    ) async {
      final fake = _Helpers(_withInvites(const [_pendingI1]));
      await _pumpPromptHost(tester, fake);
      await _pushOverHost(tester, const InviteShare(inviteId: 'i1'));
      await _pushOverHost(tester, const Text('cover'));
      // Riverpod pauses the covered screen's watch, but a resize in the same
      // frame still rebuilds it with the claim.
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = tester.view.physicalSize * 1.1;
      fake.emit(_withInvites(const [_claimed]));
      await _pumpPast(tester);
      expect(approveCode, findsOneWidget);
    });

    testWidgets('a claim that comes while Connect Now runs prompts once it '
        'finishes', (tester) async {
      final connecting = Completer<void>();
      debugConnectPersonalProxy = (tag) => connecting.future;
      addTearDown(() => debugConnectPersonalProxy = null);
      final fake = _Helpers(_withInvites(const []));
      await _pumpPromptHost(tester, fake);
      fake.emit(_withInvites(const [_claimed]));
      await tester.pumpAndSettle();
      await tester.tap(_approveYes);
      await tester.pumpAndSettle();
      await tester.tap(_approvedConnect);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      fake.emit(
        _withInvites(const [
          _claimed,
          HelperInviteView(id: 'i3', state: 'claimed', code: '7181'),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('7181'), findsNothing, reason: 'Connect Now still runs');

      connecting.complete();
      await tester.pumpAndSettle();
      expect(find.text('7181'), findsOneWidget);
    });

    testWidgets('waits for checkout to end', (tester) async {
      final fake = _Helpers(_withInvites(const []));
      await _pumpPromptHost(tester, fake);
      final container = ProviderScope.containerOf(
        tester.element(find.text('home')),
      );
      container.read(paymentSessionProvider.notifier).markRedirectInitiated();
      fake.emit(_withInvites(const [_claimed]));
      await tester.pumpAndSettle();
      expect(approveCode, findsNothing);

      container.read(paymentSessionProvider.notifier).clearRedirect();
      await tester.pumpAndSettle();
      expect(approveCode, findsOneWidget);
    });

    testWidgets('waits for the loading overlay to hide', (tester) async {
      final overlay = ValueNotifier(true);
      addTearDown(overlay.dispose);
      final fake = _Helpers(_withInvites(const []));
      await _pumpPromptHost(tester, fake, overlay: overlay);
      fake.emit(_withInvites(const [_claimed]));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(approveCode, findsNothing);
      expect(fake.approvalPrompted('i1'), isFalse);

      overlay.value = false;
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(approveCode, findsOneWidget);
    });

    testWidgets('never opens in a build without helper invites', (
      tester,
    ) async {
      HelpersNotifier.debugBuildEnabled = false;
      addTearDown(() => HelpersNotifier.debugBuildEnabled = null);
      // A build with them would prompt for this claim at once.
      final fake = _Helpers(_withInvites(const [_claimed]));
      await _pumpPromptHost(tester, fake);
      expect(approveCode, findsNothing);
      expect(fake.approvalPrompted('i1'), isFalse);
    });
  });

  testWidgets('remove all still happens when the screen closes at once', (
    tester,
  ) async {
    final fake = _Helpers(_oneHelper);
    await _pumpPushed(tester, fake, const PersonalProxiesTab());
    await tester.tap(find.byKey(const Key('personal_proxies.remove_all')));
    await tester.pumpAndSettle();
    await tester.tap(_dialogRemove);
    await tester.pump();
    // Leave PersonalProxiesTab inside AppDialog's 400 ms callback delay.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    expect(find.byType(PersonalProxiesTab), findsNothing);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fake.endAll, 1);
  });

  testWidgets('removing a helper ends that pairing', (tester) async {
    final fake = _Helpers(_oneHelper);
    await _pump(tester, fake, const PersonalProxiesTab());
    await tester.tap(find.byKey(const Key('personal_proxies.remove.p1')));
    await tester.pumpAndSettle();
    await tester.tap(_dialogRemove);
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
    await _pump(tester, fake, const PersonalProxiesTab());
    expect(find.text('invite_waiting'.i18n), findsNothing);

    await _pump(tester, fake, const InviteShare(inviteId: 'old'));
    expect(find.byKey(const Key('invite.gone')), findsOneWidget);
    expect(find.byKey(const Key('invite.qr')), findsNothing);
  });

  testWidgets('a claimed invite offers no Share, copy or QR code', (
    tester,
  ) async {
    final fake = _Helpers(
      const HelpersState(
        view: HelpersView(unlocked: true, invites: [_claimed]),
      ),
    );
    await _pump(tester, fake, const InviteShare(inviteId: 'i1'));
    expect(find.byKey(const Key('invite.share')), findsNothing);
    expect(find.text('invite_claimed_title'.i18n), findsNothing);
    expect(find.byKey(const Key('invite.waiting')), findsNothing);
    expect(find.text('https://lantern.io/help/#AAAA'), findsNothing);
  });

  testWidgets('the code is read out digit by digit', (tester) async {
    final handle = tester.ensureSemantics();
    final fake = _Helpers(const HelpersState());
    await _openApproval(tester, fake);
    expect(find.bySemanticsLabel('2 5 6 2'), findsOneWidget);
    expect(find.bySemanticsLabel('2562'), findsNothing);
    handle.dispose();
  });

  testWidgets('rename stores a nickname for that pairing', (tester) async {
    final fake = _Helpers(_oneHelper);
    await _pump(tester, fake, const PersonalProxiesTab());
    await tester.tap(find.byKey(const Key('personal_proxies.rename.p1')));
    await tester.pumpAndSettle();
    expect(find.text('personal_proxy_nickname_label'.i18n), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Cousin');
    await tester.tap(find.text('continue'.i18n));
    await tester.pumpAndSettle();
    expect(fake.renamed, [('p1', 'Cousin')]);
  });

  testWidgets('a blank nickname is sent, restoring the friend\'s own name', (
    tester,
  ) async {
    final fake = _Helpers(_oneHelper);
    await _pump(tester, fake, const PersonalProxiesTab());
    await tester.tap(find.byKey(const Key('personal_proxies.rename.p1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('continue'.i18n));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('helpers.name.error')), findsNothing);
    expect(fake.renamed, [('p1', '')]);
  });

  testWidgets('a pending invite can be cancelled', (tester) async {
    final fake = _Helpers(
      HelpersState(
        view: HelpersView(
          unlocked: true,
          invites: [
            HelperInviteView(
              id: 'i2',
              state: 'pending',
              expiresUnix: _now() + 3600,
            ),
          ],
        ),
      ),
    );
    await _pump(tester, fake, const PersonalProxiesTab());
    await tester.tap(find.byKey(const Key('personal_proxies.cancel.i2')));
    await tester.pump();
    expect(fake.forgotten, ['i2']);
  });

  testWidgets('the tab polls for online status only while shown', (
    tester,
  ) async {
    final fake = _Helpers(_oneHelper);
    await _pump(tester, fake, const PersonalProxiesTab());
    final first = fake.refreshes;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 61));
    expect(fake.refreshes, first + 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 61));
    expect(fake.refreshes, first + 1, reason: 'not while the app is behind');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 61));
    expect(fake.refreshes, first + 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 61));
    expect(fake.refreshes, first + 2, reason: 'the timer goes with the tab');
  });
}

class _Home extends HomeNotifier {
  @override
  Future<UserResponseModel> build() => Completer<UserResponseModel>().future;
}
