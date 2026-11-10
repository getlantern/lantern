import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// common.dart re-exports the generated route classes, which share the
// screens' names.
import 'package:lantern/core/common/common.dart' hide HelpFriend;
import 'package:lantern/core/common/common.dart' as routes show HelpFriend;
import 'package:lantern/core/common/common.dart' as routes_ show HelpFriend;
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/utils/deeplink_utils.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/helpers/help_friend.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/helping_friends.dart';
import 'package:lantern/features/helpers/invite_share.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:share_plus/share_plus.dart';

class _Helpers extends HelpersNotifier {
  _Helpers(
    this.initial, {
    String claimAnswer = '{"claim_id":"c1","code":"2562"}',
    List<String>? claimAnswers,
  }) : claimAnswers = claimAnswers ?? [claimAnswer];
  final HelpersState initial;

  /// Answers in turn; the last one repeats.
  final List<String> claimAnswers;
  final claims = <(String, String)>[];
  final helpOthers = <bool>[];
  final ended = <String>[];
  int refreshes = 0;
  int acknowledged = 0;

  @override
  HelpersState build() => initial;

  @override
  Future<void> refreshIfUsed() async => refreshes++;
  @override
  Future<void> loadHelpOthers() async {}
  // When set, each write of help-others stays pending until its own
  // completer here completes.
  List<Completer<void>>? helpOthersPending;
  @override
  Future<void> setHelpOthers(bool value) async {
    helpOthers.add(value);
    final pending = helpOthersPending;
    if (pending == null) return;
    final write = Completer<void>();
    pending.add(write);
    await write.future;
  }

  /// When set, each claim answers only once it completes, as the real one
  /// does after its refresh.
  Completer<void>? claimGate;

  @override
  Future<HelperResult> claim(String link, String name) async {
    claims.add((link, name));
    final i = claims.length - 1;
    await claimGate?.future;
    return HelperResult.parse(
      claimAnswers[i < claimAnswers.length ? i : claimAnswers.length - 1],
    );
  }

  @override
  Future<HelperResult> endPairing(String pairingId) async {
    ended.add(pairingId);
    return HelperResult.parse('{}');
  }

  @override
  void acknowledgeKeystoreReset() {
    acknowledged++;
    super.acknowledgeKeystoreReset();
  }

  /// Whether the approval start was held as each approval landed, as Home
  /// reads it.
  final heldAtApproval = <bool>[];

  void approve(HelpersView view) {
    heldAtApproval.add(approvalStartHeld);
    state = state.copyWith(
      view: view,
      helpingApprovals: state.helpingApprovals + 1,
    );
  }

  void setView(HelpersView view) => state = state.copyWith(view: view);
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

  int pops = 0;

  @override
  Future<bool> maybePop<T extends Object?>([T? result]) async {
    pops++;
    return true;
  }

  // pop, unlike maybePop, is not vetoed by a PopScope.
  int forcedPops = 0;

  @override
  void pop<T extends Object?>([T? result]) => forcedPops++;
}

Widget _blankPage(RouteData _) => const Scaffold(body: Text('blank'));

/// A real AppRouter with only a blank home and HelpFriend, so system Back
/// and pops go through auto_route as in the app.
class _RealRouter extends AppRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: const PageInfo('Blank', builder: _blankPage),
    ),
    AutoRoute(path: '/help-friend', page: routes_.HelpFriend.page),
  ];
}

class _Share extends ShareNotifier {
  _Share({this.active = false});
  final bool active;
  int helperStarts = 0;
  final autoEnable = <bool>[];
  @override
  ShareState build() => ShareState(active: active);
  @override
  Future<bool> ensureConsent(BuildContext context) async => true;
  @override
  Future<void> startForHelper(WidgetRef widgetRef) async => helperStarts++;
  @override
  Future<void> setAutoEnable(BuildContext context, bool enabled) async =>
      autoEnable.add(enabled);
}

/// Home's approval listener, as in home.dart.
class _HomeApprovals extends ConsumerWidget {
  const _HomeApprovals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(helpersProvider.select((s) => s.helpingApprovals), (
      prev,
      next,
    ) {
      if (next <= (prev ?? 0)) return;
      if (ref.read(helpersProvider.notifier).approvalStartHeld) return;
      ref.read(shareProvider.notifier).startForHelper(ref);
    });
    return const SizedBox();
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Helpers helpers,
  Widget child, {
  bool sharing = false,
  _Share? share,
}) async {
  // Tall enough that HelpFriend's whole form, below the "what helping
  // means" card, is built without scrolling.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 2000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        helpersProvider.overrideWith(() => helpers),
        shareProvider.overrideWith(() => share ?? _Share(active: sharing)),
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

Future<void> _claim(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('help_friend.name')), 'Ali');
  await tester.tap(find.byKey(const Key('help_friend.accept')));
  await tester.pump();
  await tester
      .pump(); // pumpAndSettle would never settle: the waiting view spins
}

/// Serves [text] as the clipboard, counting reads.
class _Clipboard {
  _Clipboard(WidgetTester tester, this.text) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method != 'Clipboard.getData') return null;
      reads++;
      return text == null ? null : {'text': text};
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  final String? text;
  int reads = 0;
}

void _desktop(bool desktop) {
  PlatformUtils.debugIsDesktop = desktop;
  addTearDown(() => PlatformUtils.debugIsDesktop = null);
}

String _linkField(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('help_friend.link')),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

const _link =
    'https://lantern.io/help/#AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

const _sara = HelperPairingView(
  pairingId: 'p1',
  name: 'Sara',
  sinceUnix: 1700000000,
);

HelpersState _helping({List<HelperPairingView> helping = const [_sara]}) =>
    HelpersState(
      helpOthers: true,
      view: HelpersView(
        unlocked: true,
        helping: helping,
        activity: const HelperActivity(
          day: '2026-10-23',
          activeSeconds: 3 * 3600 + 20 * 60,
          relayedBytes: 1200000000,
        ),
      ),
    );

const _reza = HelperPairingView(pairingId: 'p2', name: 'Reza');

// 2100-01-01: a claim that has not expired.
const _future = 4102444800;

void main() {
  setUpAll(Localization.loadTranslations);

  testWidgets('the name field capitalizes its first letter as typed', (
    tester,
  ) async {
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    final name = find.byKey(const Key('help_friend.name'));
    await tester.enterText(name, 'ali');
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: name, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      'Ali',
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: name, matching: find.byType(TextField)),
          )
          .textCapitalization,
      TextCapitalization.words,
    );
    await tester.tap(find.byKey(const Key('help_friend.accept')));
    await tester.pump();
    await tester.pump();
    expect(helpers.claims, [(_link, 'Ali')]);
  });

  testWidgets('the Keep Action Mode on card has room below its text', (
    tester,
  ) async {
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    helpers.approve(const HelpersView(unlocked: true, helping: [_sara]));
    await tester.pump();
    final card = find.ancestor(
      of: find.byKey(const Key('help_friend.keep_on')),
      matching: find.byType(AppCard),
    );
    final body = find.text('help_friend_keep_on_body'.i18n.fill(['Sara']));
    expect(body, findsOneWidget);
    expect(
      tester.getRect(card).bottom - tester.getRect(body).bottom,
      greaterThanOrEqualTo(12),
    );
  });

  testWidgets('claiming shows the code', (tester) async {
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    expect(helpers.claims, [(_link, 'Ali')]);
    expect(find.text('2562'), findsOneWidget);
    expect(find.text('become_personal_proxy'.i18n), findsOneWidget);
    final card = find.byKey(const Key('help_friend.waiting'));
    for (final text in [
      'help_friend_tell_code'.i18n,
      '2562',
      'help_friend_code_check'.i18n,
      'help_friend_waiting_approval'.i18n,
    ]) {
      expect(
        find.descendant(of: card, matching: find.text(text)),
        findsOneWidget,
      );
    }
    final code = tester.widget<Text>(find.byKey(const Key('help_friend.code')));
    expect(
      code.style?.fontSize,
      Theme.of(tester.element(card)).textTheme.displayMedium?.fontSize,
    );
    final note = find.byKey(const Key('help_friend.code_note'));
    expect(
      find.descendant(
        of: note,
        matching: find.text('help_friend_code_note'.i18n),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(note).dy,
      greaterThan(tester.getBottomLeft(card).dy),
    );
  });

  testWidgets('an already claimed invite says so prominently', (tester) async {
    final helpers = _Helpers(
      const HelpersState(),
      claimAnswer: '{"error":"already_claimed"}',
    );
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    expect(
      find.byKey(const Key('help_friend.already_claimed')),
      findsOneWidget,
    );
    expect(find.text('help_friend_already_claimed_title'.i18n), findsOneWidget);
  });

  testWidgets('a link this device already helps for says so, without the '
      'compromised-link warning', (tester) async {
    final helpers = _Helpers(
      const HelpersState(view: HelpersView(unlocked: true, helping: [_sara])),
      claimAnswer: '{"error":"already_helping"}',
    );
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    expect(
      find.byKey(const Key('help_friend.already_helping')),
      findsOneWidget,
    );
    expect(
      find.text('help_friend_already_helping_named'.i18n.fill(['Sara'])),
      findsOneWidget,
    );
    expect(find.byKey(const Key('help_friend.already_claimed')), findsNothing);
    expect(find.text('help_friend_already_claimed_body'.i18n), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('already helping is generic when the pairing is ambiguous', (
    tester,
  ) async {
    final helpers = _Helpers(
      const HelpersState(
        view: HelpersView(unlocked: true, helping: [_sara, _reza]),
      ),
      claimAnswer: '{"error":"already_helping"}',
    );
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    expect(find.text(helperErrorText('already_helping')), findsOneWidget);
    expect(find.textContaining('Sara'), findsNothing);
  });

  testWidgets('without a link, HelpFriend reopens the latest pending code', (
    tester,
  ) async {
    final helpers = _Helpers(
      const HelpersState(
        view: HelpersView(
          unlocked: true,
          claims: [
            HelperClaimView(id: 'c1', code: '1111', expiresUnix: _future),
            HelperClaimView(id: 'c2', code: '2562', expiresUnix: _future + 1),
          ],
        ),
      ),
    );
    await _pump(tester, helpers, const HelpFriend());
    await tester.pump();
    expect(find.byKey(const Key('help_friend.code')), findsOneWidget);
    expect(find.text('2562'), findsOneWidget);
    expect(find.byKey(const Key('help_friend.link')), findsNothing);
    expect(helpers.claims, isEmpty, reason: 'nothing is claimed again');
    // c2 became Reza's pairing; c1 still waits.
    helpers.approve(
      const HelpersView(
        unlocked: true,
        helping: [_reza],
        claims: [HelperClaimView(id: 'c1', code: '1111', expiresUnix: _future)],
      ),
    );
    await tester.pump();
    expect(
      find.text('help_friend_success_title'.i18n.fill(['Reza'])),
      findsOneWidget,
    );
  });

  testWidgets('a provisional claim is not resumed; the retry stays', (
    tester,
  ) async {
    final helpers = _Helpers(
      const HelpersState(),
      claimAnswer: '{"error":"unavailable"}',
    );
    await _pump(tester, helpers, const HelpFriend());
    await tester.enterText(find.byKey(const Key('help_friend.link')), _link);
    await _claim(tester);
    expect(find.byKey(const Key('help_friend.error')), findsOneWidget);
    // The engine kept the claim it could not confirm, for a retry.
    helpers.approve(
      const HelpersView(
        unlocked: true,
        claims: [
          HelperClaimView(
            id: 'c1',
            code: '2562',
            expiresUnix: _future,
            provisional: true,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('help_friend.code')), findsNothing);
    expect(find.byKey(const Key('help_friend.error')), findsOneWidget);
    expect(find.byKey(const Key('help_friend.accept')), findsOneWidget);
    expect(find.byKey(const Key('help_friend.link')), findsOneWidget);
  });

  testWidgets('a provisional or expired claim is not reopened', (tester) async {
    final helpers = _Helpers(
      const HelpersState(
        view: HelpersView(
          unlocked: true,
          claims: [
            HelperClaimView(
              id: 'c1',
              code: '1111',
              expiresUnix: _future,
              provisional: true,
            ),
            HelperClaimView(id: 'c2', code: '2562', expiresUnix: 100),
          ],
        ),
      ),
    );
    await _pump(tester, helpers, const HelpFriend());
    await tester.pump();
    expect(find.byKey(const Key('help_friend.code')), findsNothing);
    expect(find.byKey(const Key('help_friend.link')), findsOneWidget);
  });

  testWidgets('a link that opened HelpFriend and the engine refuses shows '
      'the error on the field, and can be corrected', (tester) async {
    final helpers = _Helpers(
      const HelpersState(),
      claimAnswers: ['{"error":"bad_link"}', '{"claim_id":"c1","code":"2562"}'],
    );
    helpers.holdLink('https://lantern.io/help/#broken');
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    expect(_linkField(tester), 'https://lantern.io/help/#broken');
    await _claim(tester);
    expect(find.byKey(const Key('help_friend.link')), findsOneWidget);
    expect(find.text('help_friend_form_title'.i18n), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('help_friend.link_error'))).data,
      helperErrorText('bad_link'),
    );
    expect(find.byKey(const Key('help_friend.error')), findsNothing);
    // The error takes the helper line's place; correcting the link brings
    // it back.
    expect(find.byKey(const Key('help_friend.ask_invite')), findsNothing);
    await tester.enterText(find.byKey(const Key('help_friend.link')), _link);
    await tester.pump();
    expect(find.byKey(const Key('help_friend.link_error')), findsNothing);
    expect(find.byKey(const Key('help_friend.ask_invite')), findsOneWidget);
    await tester.tap(find.byKey(const Key('help_friend.accept')));
    await tester.pump();
    await tester.pump();
    expect(helpers.claims.last, (_link, 'Ali'));
    expect(find.text('2562'), findsOneWidget);
  });

  testWidgets('a link that opened HelpFriend and the engine reports as the '
      'volunteer\'s own invite shows the error on the field, without asking '
      'for an invite', (tester) async {
    final helpers = _Helpers(
      const HelpersState(),
      claimAnswers: ['{"error":"own_invite"}'],
    );
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    expect(find.byKey(const Key('help_friend.link')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('help_friend.link_error'))).data,
      helperErrorText('own_invite'),
    );
    expect(find.byKey(const Key('help_friend.ask_invite')), findsNothing);
  });

  testWidgets('the button waits for a valid link; a bad one is flagged on '
      'the field', (tester) async {
    final helpers = _Helpers(const HelpersState());
    await _pump(tester, helpers, const HelpFriend());
    PrimaryButton button() => tester.widget<PrimaryButton>(
      find.descendant(
        of: find.byKey(const Key('help_friend.accept')),
        matching: find.byType(PrimaryButton),
      ),
    );
    expect(button().enabled, isFalse);
    expect(find.byKey(const Key('help_friend.link_error')), findsNothing);
    expect(find.text('help_friend_no_link_yet'.i18n), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('help_friend.link')),
      'https://example.com/help#AAAA',
    );
    await tester.pump();
    expect(button().enabled, isFalse);
    expect(
      tester.widget<Text>(find.byKey(const Key('help_friend.link_error'))).data,
      helperErrorText('bad_link'),
    );
    await tester.tap(find.byKey(const Key('help_friend.accept')));
    await tester.pump();
    expect(helpers.claims, isEmpty);

    // Pasted with the share message around it.
    await tester.enterText(
      find.byKey(const Key('help_friend.link')),
      'Sara wants your help staying online. $_link',
    );
    await tester.pump();
    expect(button().enabled, isTrue);
    expect(find.byKey(const Key('help_friend.link_error')), findsNothing);
  });

  testWidgets('opening HelpFriend refreshes only if used, takes the held '
      'link once, and caps the name at 60', (tester) async {
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    expect(helpers.refreshes, 1);
    expect(helpers.takeLink(), isNull);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('help_friend.name')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.maxLength, 60);
  });

  testWidgets('before claiming: what being a Personal Proxy means, then the '
      'link and name card', (tester) async {
    final helpers = _Helpers(const HelpersState());
    await _pump(tester, helpers, const HelpFriend());
    expect(find.text('become_personal_proxy'.i18n), findsOneWidget);
    final card = find.byKey(const Key('help_friend.means'));
    expect(card, findsOneWidget);
    for (final key in [
      'become_means_title',
      'become_means_traffic',
      'become_means_seen',
      'become_means_remove',
    ]) {
      expect(
        find.descendant(of: card, matching: find.text(key.i18n)),
        findsOneWidget,
      );
    }
    // Decision 5: never "you cannot see it".
    expect(find.textContaining('cannot see'), findsNothing);
    final form = find.byKey(const Key('help_friend.form'));
    for (final text in [
      'help_friend_form_title'.i18n,
      'help_friend_link_label'.i18n,
      'help_friend_no_link_yet'.i18n,
      'help_friend_ask_send_link'.i18n,
      'help_friend_name_label'.i18n,
      'help_friend_name_hint_server_list'.i18n,
      'help_friend_become'.i18n,
    ]) {
      expect(
        find.descendant(of: form, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(tester.getBottomLeft(card).dy, lessThan(tester.getTopLeft(form).dy));
  });

  testWidgets('without a held link, the link field is shown', (tester) async {
    final helpers = _Helpers(const HelpersState());
    await _pump(tester, helpers, const HelpFriend());
    expect(find.byKey(const Key('help_friend.link')), findsOneWidget);
  });

  testWidgets('a pasted lantern:// link is claimed in canonical form', (
    tester,
  ) async {
    final helpers = _Helpers(const HelpersState());
    await _pump(tester, helpers, const HelpFriend());
    await tester.enterText(
      find.byKey(const Key('help_friend.link')),
      '${AppBuildInfo.appAuthScheme}://help#AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
    );
    await _claim(tester);
    expect(helpers.claims.single.$1, _link);
  });

  testWidgets('a link that opened HelpFriend stays in its field, filled in, '
      'with the paste icon, and is claimed', (tester) async {
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    expect(find.byKey(const Key('help_friend.link')), findsOneWidget);
    expect(_linkField(tester), _link);
    final paste = find.byKey(const Key('help_friend.paste_button'));
    expect(
      find.descendant(
        of: find.byKey(const Key('help_friend.link')),
        matching: paste,
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<IconButton>(paste).tooltip,
      'help_friend_paste_button'.i18n,
    );
    // No separate "Paste link" text button any more.
    expect(find.text('help_friend_paste_button'.i18n), findsNothing);
    expect(find.text('help_friend_form_title'.i18n), findsOneWidget);
    expect(
      tester
          .widget<PrimaryButton>(
            find.descendant(
              of: find.byKey(const Key('help_friend.accept')),
              matching: find.byType(PrimaryButton),
            ),
          )
          .enabled,
      isTrue,
    );
    await _claim(tester);
    expect(helpers.claims, [(_link, 'Ali')]);
  });

  testWidgets('without a link, the volunteer can ask a friend for an invite '
      'through the share sheet', (tester) async {
    final shared = <ShareParams>[];
    debugShareInvite = (p) async => shared.add(p);
    addTearDown(() => debugShareInvite = null);
    final helpers = _Helpers(const HelpersState());
    await _pump(tester, helpers, const HelpFriend());
    final ask = find.byKey(const Key('help_friend.ask_invite'));
    expect(ask, findsOneWidget);
    expect(find.text('help_friend_no_link_yet'.i18n), findsOneWidget);
    expect(find.text('help_friend_ask_send_link'.i18n), findsOneWidget);
    // The link field's helper line, between the link and the name.
    expect(
      tester.getTopLeft(ask).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('help_friend.link'))).dy,
      ),
    );
    expect(
      tester.getBottomLeft(ask).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('help_friend.name'))).dy),
    );
    await tester.tap(ask);
    await tester.pump();
    expect(shared.single.text, 'help_friend_ask_invite_message'.i18n);
    expect(shared.single.text, contains('"${'invite_personal_proxy'.i18n}"'));
    expect(shared.single.text, contains('server_selection'.i18n));
    expect(shared.single.sharePositionOrigin!.isEmpty, isFalse);
    expect(helpers.claims, isEmpty);
  });

  testWidgets('a link that opened HelpFriend still offers the ask for an '
      'invite under its field', (tester) async {
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    expect(find.byKey(const Key('help_friend.ask_invite')), findsOneWidget);
    expect(find.text('help_friend_no_link_yet'.i18n), findsOneWidget);
  });

  testWidgets('Paste fills the link field from the clipboard; mobile reads '
      'it only on the tap', (tester) async {
    _desktop(false);
    final clipboard = _Clipboard(tester, '  $_link\n');
    final helpers = _Helpers(const HelpersState());
    await _pump(tester, helpers, const HelpFriend());
    await tester.pump();
    expect(clipboard.reads, 0);
    expect(_linkField(tester), isEmpty);
    await tester.tap(find.byKey(const Key('help_friend.paste_button')));
    await tester.pump();
    expect(clipboard.reads, 1);
    expect(_linkField(tester), _link);
    await _claim(tester);
    expect(helpers.claims, [(_link, 'Ali')]);
  });

  testWidgets('Paste with nothing on the clipboard leaves the field', (
    tester,
  ) async {
    _desktop(false);
    _Clipboard(tester, null);
    await _pump(tester, _Helpers(const HelpersState()), const HelpFriend());
    await tester.enterText(find.byKey(const Key('help_friend.link')), 'abc');
    await tester.tap(find.byKey(const Key('help_friend.paste_button')));
    await tester.pump();
    expect(_linkField(tester), 'abc');
  });

  testWidgets('on desktop, an invite on the clipboard is filled in', (
    tester,
  ) async {
    _desktop(true);
    final clipboard = _Clipboard(tester, 'Sara wants your help. $_link');
    await _pump(tester, _Helpers(const HelpersState()), const HelpFriend());
    await tester.pump();
    expect(clipboard.reads, 1);
    expect(_linkField(tester), 'Sara wants your help. $_link');
    expect(find.byKey(const Key('help_friend.link_error')), findsNothing);
  });

  testWidgets('on desktop, clipboard text that is not an invite is dropped', (
    tester,
  ) async {
    _desktop(true);
    final clipboard = _Clipboard(tester, 'https://example.com/help#AAAA');
    await _pump(tester, _Helpers(const HelpersState()), const HelpFriend());
    await tester.pump();
    expect(clipboard.reads, 1);
    expect(_linkField(tester), isEmpty);
  });

  testWidgets('a link that opened HelpFriend is not overridden by the '
      'clipboard', (tester) async {
    _desktop(true);
    final clipboard = _Clipboard(tester, _link);
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink('https://lantern.io/help/#BBBB');
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await tester.pump();
    expect(clipboard.reads, 0);
  });

  testWidgets('approval after the claim says so', (tester) async {
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    helpers.approve(const HelpersView(unlocked: true, helping: [_sara]));
    await tester.pump();
    expect(find.byKey(const Key('help_friend.approved')), findsOneWidget);
    expect(find.byKey(const Key('help_friend.code')), findsNothing);
  });

  // The claim answer is c1; the real notifier's refresh puts it in the view.
  HelpersState waitingOnC1() => const HelpersState(
    view: HelpersView(
      unlocked: true,
      claims: [HelperClaimView(id: 'c1', code: '2562', expiresUnix: _future)],
    ),
  );

  testWidgets('another claim\'s approval does not end this wait', (
    tester,
  ) async {
    final helpers = _Helpers(waitingOnC1());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    helpers.approve(
      const HelpersView(
        unlocked: true,
        helping: [_reza],
        claims: [HelperClaimView(id: 'c1', code: '2562', expiresUnix: _future)],
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('help_friend.approved')), findsNothing);
    expect(find.byKey(const Key('help_friend.gone')), findsNothing);
    expect(find.byKey(const Key('help_friend.code')), findsOneWidget);
  });

  testWidgets('this claim becoming a pairing is approved, by name', (
    tester,
  ) async {
    final helpers = _Helpers(waitingOnC1());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    helpers.approve(const HelpersView(unlocked: true, helping: [_sara]));
    await tester.pump();
    expect(
      find.text('help_friend_success_title'.i18n.fill(['Sara'])),
      findsOneWidget,
    );
  });

  Future<(_Share, _Router)> approvedScreen(WidgetTester tester) async {
    await sl.reset();
    final router = _Router();
    sl.registerSingleton<AppRouter>(router);
    addTearDown(sl.reset);
    final share = _Share();
    final helpers = _Helpers(waitingOnC1());
    helpers.holdLink(_link);
    await _pump(
      tester,
      helpers,
      const HelpFriend(fromLink: true),
      share: share,
    );
    await _claim(tester);
    expect(helpers.approvalStartHeld, isTrue);
    helpers.approve(const HelpersView(unlocked: true, helping: [_sara]));
    await tester.pump();
    // The approval is the success screen's to act on, not Home's.
    expect(helpers.approvalStartHeld, isTrue);
    return (share, router);
  }

  testWidgets('the success screen names the friend and asks to keep Action '
      'Mode on, checked by default, with no back arrow', (tester) async {
    await approvedScreen(tester);
    expect(
      find.text('help_friend_success_title'.i18n.fill(['Sara'])),
      findsOneWidget,
    );
    expect(
      find.text('help_friend_success_body'.i18n.fill(['Sara'])),
      findsOneWidget,
    );
    expect(find.text('help_friend_keep_on'.i18n), findsOneWidget);
    expect(
      find.text('help_friend_keep_on_body'.i18n.fill(['Sara'])),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const Key('help_friend.keep_on.checkbox')),
          )
          .value,
      isTrue,
    );
    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('Done with the box checked turns Action Mode on and sets '
      'auto-enable', (tester) async {
    final (share, router) = await approvedScreen(tester);
    await tester.tap(find.byKey(const Key('help_friend.done')));
    await tester.pump();
    expect(share.helperStarts, 1);
    expect(share.autoEnable, [true]);
    expect(
      router.forcedPops,
      1,
      reason: 'the screen\'s PopScope vetoes maybePop',
    );
    await tester.tap(find.byKey(const Key('help_friend.done')));
    await tester.pump();
    expect(share.helperStarts, 1, reason: 'Done acts once');
  });

  testWidgets('Back leaves the success screen without turning Action Mode '
      'on, even with the box checked', (tester) async {
    final (share, router) = await approvedScreen(tester);
    tester
        .widget<PopScope<Object?>>(
          find.byWidgetPredicate((w) => w is PopScope<Object?>).last,
        )
        .onPopInvokedWithResult!(false, null);
    await tester.pump();
    expect(share.helperStarts, 0);
    expect(share.autoEnable, isEmpty);
    expect(router.forcedPops, 1);
  });

  /// The success screen pushed through a real AppRouter over a blank home.
  Future<(_Share, _RealRouter)> approvedThroughRouter(
    WidgetTester tester,
  ) async {
    await sl.reset();
    final router = _RealRouter();
    sl.registerSingleton<AppRouter>(router);
    addTearDown(sl.reset);
    final share = _Share();
    final helpers = _Helpers(waitingOnC1());
    helpers.holdLink(_link);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          helpersProvider.overrideWith(() => helpers),
          shareProvider.overrideWith(() => share),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          child: MaterialApp.router(
            theme: AppTheme.appTheme(),
            routerConfig: router.config(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('blank'), findsOneWidget);
    unawaited(router.push(routes_.HelpFriend(fromLink: true)));
    await tester.pumpAndSettle();
    await _claim(tester);
    helpers.approve(const HelpersView(unlocked: true, helping: [_sara]));
    await tester.pump();
    expect(find.byKey(const Key('help_friend.approved')), findsOneWidget);
    return (share, router);
  }

  testWidgets('system Back through the real router closes the success '
      'screen without turning Action Mode on', (tester) async {
    final (share, router) = await approvedThroughRouter(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HelpFriend), findsNothing);
    expect(find.text('blank'), findsOneWidget);
    expect(router.stack, hasLength(1));
    expect(share.helperStarts, 0);
    expect(share.autoEnable, isEmpty);
  });

  testWidgets('Done through the real router closes the success screen and '
      'turns Action Mode on', (tester) async {
    final (share, router) = await approvedThroughRouter(tester);
    await tester.tap(find.byKey(const Key('help_friend.done')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HelpFriend), findsNothing);
    expect(router.stack, hasLength(1));
    expect(share.helperStarts, 1);
    expect(share.autoEnable, [true]);
  });

  testWidgets('Done with the box unchecked pairs without turning Action Mode '
      'on or touching auto-enable', (tester) async {
    final (share, router) = await approvedScreen(tester);
    await tester.tap(find.byKey(const Key('help_friend.keep_on')));
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(
            find.byKey(const Key('help_friend.keep_on.checkbox')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('help_friend.done')));
    await tester.pump();
    expect(share.helperStarts, 0);
    expect(share.autoEnable, isEmpty);
    expect(
      router.forcedPops,
      1,
      reason: 'the screen\'s PopScope vetoes maybePop',
    );
  });

  testWidgets('HelpFriend holds the approval start only while it waits on '
      'its claim', (tester) async {
    final helpers = _Helpers(waitingOnC1());
    helpers.holdLink(_link);
    final show = ValueNotifier(true);
    await _pump(
      tester,
      helpers,
      ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (_, on, _) =>
            on ? const HelpFriend(fromLink: true) : const SizedBox(),
      ),
    );
    expect(helpers.approvalStartHeld, isFalse);
    await _claim(tester);
    expect(helpers.approvalStartHeld, isTrue);
    show.value = false;
    await tester.pump();
    expect(helpers.approvalStartHeld, isFalse);
  });

  /// HelpFriend over Home's approval listener (home.dart), which starts
  /// sharing for a new approval unless a HelpFriend holds the start.
  Future<(_Helpers, _Share, ValueNotifier<bool>)> overHome(
    WidgetTester tester,
    _Helpers helpers,
    HelpFriend screen,
  ) async {
    await sl.reset();
    sl.registerSingleton<AppRouter>(_Router());
    addTearDown(sl.reset);
    final share = _Share();
    final show = ValueNotifier(true);
    await _pump(
      tester,
      helpers,
      Column(
        children: [
          const _HomeApprovals(),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (_, on, _) => on ? screen : const SizedBox(),
            ),
          ),
        ],
      ),
      share: share,
    );
    return (helpers, share, show);
  }

  for (final ok in [true, false]) {
    testWidgets('an approval arriving before the claim answers is held '
        '(claim ${ok ? 'succeeds' : 'fails'})', (tester) async {
      final helpers = _Helpers(
        waitingOnC1(),
        claimAnswer: ok
            ? '{"claim_id":"c1","code":"2562"}'
            : '{"error":"unavailable"}',
      )..claimGate = Completer<void>();
      helpers.holdLink(_link);
      final (_, share, _) = await overHome(
        tester,
        helpers,
        const HelpFriend(fromLink: true),
      );
      await _claim(tester);
      expect(helpers.claims, hasLength(1));
      // The claim's refresh, or a poll, brings the approval before the
      // claim answers.
      helpers.approve(const HelpersView(unlocked: true, helping: [_sara]));
      expect(helpers.heldAtApproval, [true]);
      helpers.claimGate!.complete();
      await tester.pump();
      await tester.pump();
      if (ok) {
        expect(
          find.text('help_friend_success_title'.i18n.fill(['Sara'])),
          findsOneWidget,
        );
        expect(share.helperStarts, 0, reason: 'the success screen asks');
        await tester.tap(find.byKey(const Key('help_friend.done')));
        await tester.pump();
        expect(share.helperStarts, 1);
      } else {
        expect(find.byKey(const Key('help_friend.error')), findsOneWidget);
        expect(helpers.approvalStartHeld, isFalse);
        await tester.pump();
        expect(
          share.helperStarts,
          0,
          reason: 'no success screen asked: sharing waits for the user',
        );
      }
    });
  }

  testWidgets('an approval held while waiting starts nothing when the '
      'screen closes without asking', (tester) async {
    final helpers = _Helpers(waitingOnC1());
    helpers.holdLink(_link);
    final (_, share, show) = await overHome(
      tester,
      helpers,
      const HelpFriend(fromLink: true),
    );
    await _claim(tester);
    // Another claim's approval: this one still waits.
    helpers.approve(
      const HelpersView(
        unlocked: true,
        helping: [_reza],
        claims: [HelperClaimView(id: 'c1', code: '2562', expiresUnix: _future)],
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('help_friend.code')), findsOneWidget);
    expect(share.helperStarts, 0);
    show.value = false;
    await tester.pump();
    await tester.pump();
    expect(helpers.approvalStartHeld, isFalse);
    expect(share.helperStarts, 0);
  });

  testWidgets('a success screen closed without Done starts nothing', (
    tester,
  ) async {
    final helpers = _Helpers(waitingOnC1());
    helpers.holdLink(_link);
    final (_, share, show) = await overHome(
      tester,
      helpers,
      const HelpFriend(fromLink: true),
    );
    await _claim(tester);
    helpers.approve(const HelpersView(unlocked: true, helping: [_sara]));
    await tester.pump();
    expect(find.byKey(const Key('help_friend.approved')), findsOneWidget);
    show.value = false;
    await tester.pump();
    await tester.pump();
    expect(share.helperStarts, 0);
    expect(helpers.approvalStartHeld, isFalse);
  });

  testWidgets('a resumed claim holds the approval start from the first '
      'frame, and its approval reaches the success screen', (tester) async {
    final helpers = _Helpers(waitingOnC1());
    final (_, share, _) = await overHome(tester, helpers, const HelpFriend());
    expect(find.byKey(const Key('help_friend.code')), findsOneWidget);
    expect(helpers.approvalStartHeld, isTrue);
    helpers.approve(const HelpersView(unlocked: true, helping: [_sara]));
    await tester.pump();
    expect(
      find.text('help_friend_success_title'.i18n.fill(['Sara'])),
      findsOneWidget,
    );
    expect(share.helperStarts, 0);
    await tester.tap(find.byKey(const Key('help_friend.done')));
    await tester.pump();
    expect(share.helperStarts, 1);
  });

  testWidgets('this claim leaving without a pairing ends the wait', (
    tester,
  ) async {
    final helpers = _Helpers(waitingOnC1());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    expect(find.byKey(const Key('help_friend.code')), findsOneWidget);
    // Rejected, expired or pruned: gone from the view, and no new pairing.
    helpers.setView(const HelpersView(unlocked: true));
    await tester.pump();
    expect(find.byKey(const Key('help_friend.gone')), findsOneWidget);
    expect(find.text('help_friend_no_longer_pending'.i18n), findsOneWidget);
    expect(find.byKey(const Key('help_friend.code')), findsNothing);
    expect(find.byKey(const Key('help_friend.approved')), findsNothing);
  });

  testWidgets('a claim whose refresh failed keeps waiting', (tester) async {
    // The claim answer came back but the view still predates it.
    final helpers = _Helpers(
      const HelpersState(view: HelpersView(unlocked: true)),
    );
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    await tester.pump();
    expect(find.byKey(const Key('help_friend.code')), findsOneWidget);
    expect(find.byKey(const Key('help_friend.gone')), findsNothing);
  });

  testWidgets('the code is spoken digit by digit', (tester) async {
    final handle = tester.ensureSemantics();
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    expect(find.bySemanticsLabel('2 5 6 2'), findsOneWidget);
    expect(find.bySemanticsLabel('2562'), findsNothing);
    handle.dispose();
  });

  testWidgets('a claim answer without a code is an error, not silence', (
    tester,
  ) async {
    final helpers = _Helpers(
      const HelpersState(),
      claimAnswer: '{"claim_id":"c1"}',
    );
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    expect(find.byKey(const Key('help_friend.code')), findsNothing);
    expect(find.byKey(const Key('help_friend.error')), findsOneWidget);
    expect(find.text(helperErrorText('unavailable')), findsOneWidget);
  });

  testWidgets('a retry after an error reuses the held link', (tester) async {
    final helpers = _Helpers(
      const HelpersState(),
      claimAnswers: [
        '{"error":"unavailable"}',
        '{"claim_id":"c1","code":"2562"}',
      ],
    );
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    expect(find.byKey(const Key('help_friend.error')), findsOneWidget);
    expect(_linkField(tester), _link);
    await tester.tap(find.byKey(const Key('help_friend.accept')));
    await tester.pump();
    await tester
        .pump(); // pumpAndSettle would never settle: the waiting view spins
    expect(helpers.claims, [(_link, 'Ali'), (_link, 'Ali')]);
    expect(find.text('2562'), findsOneWidget);
  });

  testWidgets('approval names the pairing from this claim, not the last one', (
    tester,
  ) async {
    final helpers = _Helpers(
      const HelpersState(view: HelpersView(unlocked: true, helping: [_sara])),
    );
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    // The engine dropped claim c1 when its key opened Reza's name.
    helpers.approve(const HelpersView(unlocked: true, helping: [_reza, _sara]));
    await tester.pump();
    expect(find.byKey(const Key('help_friend.approved')), findsOneWidget);
    expect(
      find.text('help_friend_success_title'.i18n.fill(['Reza'])),
      findsOneWidget,
    );
  });

  testWidgets('approval uses the generic name when the pairing is ambiguous', (
    tester,
  ) async {
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    helpers.approve(const HelpersView(unlocked: true, helping: [_sara, _reza]));
    await tester.pump();
    expect(
      find.text(
        'help_friend_success_title'.i18n.fill(['helping_unnamed'.i18n]),
      ),
      findsOneWidget,
    );
  });

  testWidgets('approval uses the generic name while this claim is pending', (
    tester,
  ) async {
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    await _claim(tester);
    // Another claim's pairing arrived; c1 is still waiting.
    helpers.approve(
      const HelpersView(
        unlocked: true,
        helping: [_reza],
        claims: [HelperClaimView(id: 'c1', code: '2562')],
      ),
    );
    await tester.pump();
    expect(find.textContaining('Reza'), findsNothing);
  });

  testWidgets(
    'HelpFriend shows the keystore-reset notice and acknowledges it',
    (tester) async {
      final helpers = _Helpers(const HelpersState(keystoreReset: true));
      await _pump(tester, helpers, const HelpFriend());
      expect(find.byKey(const Key('helping.keystore_reset')), findsOneWidget);
      await tester.tap(find.byKey(const Key('helping.keystore_reset.dismiss')));
      await tester.pump();
      expect(helpers.acknowledged, 1);
      expect(find.byKey(const Key('helping.keystore_reset')), findsNothing);
    },
  );

  testWidgets('the connections card counts friends and opens the sheet', (
    tester,
  ) async {
    final helpers = _Helpers(_helping());
    await _pump(tester, helpers, const PersonalProxyConnectionsCard());
    expect(find.text('helping_connections_title'.i18n), findsOneWidget);
    expect(find.text('helping_friends_one'.i18n), findsOneWidget);
    // Live status is not reported yet: no third line rather than a wrong one.
    expect(find.textContaining('connected right now'), findsNothing);
    await tester.tap(
      find.byKey(const Key('action_mode.personal_proxy_connections')),
    );
    await tester.pumpAndSettle();
    expect(find.text('helping_sheet_title'.i18n), findsOneWidget);
    expect(find.byType(HelpingFriendsSheet), findsOneWidget);
  });

  testWidgets('with live status, the card names the one friend connected', (
    tester,
  ) async {
    final helpers = _Helpers(
      _helping(
        helping: const [
          HelperPairingView(pairingId: 'p1', name: 'Sara', connected: true),
          HelperPairingView(pairingId: 'p2', name: 'Reza', connected: false),
        ],
      ),
    );
    await _pump(tester, helpers, const PersonalProxyConnectionsCard());
    expect(find.text('helping_friends_count'.i18n.fill([2])), findsOneWidget);
    expect(
      find.text('helping_connected_named'.i18n.fill(['Sara'])),
      findsOneWidget,
    );
  });

  testWidgets('live status: the card and sheet follow it, the headline names '
      'the first connected friend, and unknown hides it again', (tester) async {
    const unknown = [
      HelperPairingView(pairingId: 'p1', name: 'Sara'),
      HelperPairingView(pairingId: 'p2', name: 'Reza'),
    ];
    final helpers = _Helpers(_helping(helping: unknown));
    await _pump(
      tester,
      helpers,
      const Column(
        children: [
          PersonalProxyConnectionsCard(),
          Expanded(child: HelpingFriendsSheet()),
        ],
      ),
      sharing: true,
    );
    expect(find.textContaining('connected right now'), findsNothing);
    expect(find.byKey(const Key('helping.status.p1')), findsNothing);
    expect(find.byKey(const Key('helping.status.p2')), findsNothing);

    helpers.setView(
      _helping(
        helping: const [
          HelperPairingView(pairingId: 'p1', name: 'Sara', connected: false),
          HelperPairingView(pairingId: 'p2', name: 'Reza', connected: true),
        ],
      ).view,
    );
    await tester.pump();
    expect(
      find.text('helping_connected_named'.i18n.fill(['Reza'])),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('helping.status.p1'))).data,
      'helping_not_connected'.i18n,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('helping.status.p2'))).data,
      'helping_connected'.i18n,
    );

    helpers.setView(_helping(helping: unknown).view);
    await tester.pump();
    expect(find.textContaining('connected right now'), findsNothing);
    expect(find.byKey(const Key('helping.status.p2')), findsNothing);
  });

  testWidgets('a friend\'s status at large text on a narrow phone leaves '
      'room for the name and Remove', (tester) async {
    final helpers = _Helpers(
      _helping(
        helping: const [
          HelperPairingView(
            pairingId: 'p1',
            name: 'Sara',
            sinceUnix: 1700000000,
            connected: false,
          ),
        ],
      ),
    );
    await _pump(
      tester,
      helpers,
      const MediaQuery(
        data: MediaQueryData(
          size: Size(320, 2000),
          textScaler: TextScaler.linear(2),
        ),
        child: Center(
          child: SizedBox(width: 320, child: HelpingFriendsSheet()),
        ),
      ),
      sharing: true,
    );
    expect(tester.takeException(), isNull);
    final name = find.text('Sara');
    expect(tester.getSize(name).width, greaterThan(40));
    final remove = find.byKey(const Key('helping.remove.p1'));
    final row = find.byKey(const Key('helping.friend.p1'));
    expect(
      tester.getRect(remove).right,
      lessThanOrEqualTo(tester.getRect(row).right),
    );
    expect(tester.getSize(remove).width, greaterThanOrEqualTo(40));
  });

  test('connectedRightNow: unknown, one by name, else a count', () {
    const known = HelperPairingView(pairingId: 'a', name: 'A', connected: true);
    const off = HelperPairingView(pairingId: 'b', name: 'B', connected: false);
    const unknown = HelperPairingView(pairingId: 'c', name: 'C');
    expect(connectedRightNow(const []), isNull);
    expect(connectedRightNow(const [known, unknown]), isNull);
    expect(
      connectedRightNow(const [known, off]),
      'helping_connected_named'.i18n.fill(['A']),
    );
    expect(
      connectedRightNow(const [off]),
      'helping_connected_count'.i18n.fill([0]),
    );
    expect(
      connectedRightNow(const [known, known]),
      'helping_connected_count'.i18n.fill([2]),
    );
  });

  test('connected is read when reported, and null otherwise', () {
    expect(
      HelperPairingView.fromJson(const {
        'pairing_id': 'p',
        'connected': true,
      }).connected,
      isTrue,
    );
    expect(
      HelperPairingView.fromJson(const {
        'pairing_id': 'p',
        'connected': false,
      }).connected,
      isFalse,
    );
    expect(
      HelperPairingView.fromJson(const {'pairing_id': 'p'}).connected,
      isNull,
    );
    expect(
      HelperPairingView.fromJson(const {
        'pairing_id': 'p',
        'connected': 'yes',
      }).connected,
      isNull,
    );
  });

  testWidgets('the friends sheet: rows, paste another, who else is helped, '
      'and data relayed, with no help-others switch', (tester) async {
    final helpers = _Helpers(_helping());
    await _pump(tester, helpers, const HelpingFriendsSheet(), sharing: true);
    expect(find.text('helping_your_friends'.i18n), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text(helperSinceLabel(1700000000)), findsOneWidget);
    // No live status yet: no Connected or Not connected.
    expect(find.byKey(const Key('helping.status.p1')), findsNothing);
    expect(find.byKey(const Key('helping.remove.p1')), findsOneWidget);
    expect(find.byKey(const Key('helping.paste_another')), findsOneWidget);
    expect(find.text('helping_paste_another'.i18n), findsOneWidget);
    final data = find.byKey(const Key('helping.data_relayed'));
    expect(
      find.descendant(of: data, matching: find.text(1200000000.siBytes)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: data,
        matching: find.text(
          'helping_active_today'.i18n.fill([helpingDuration(12000)]),
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('helping.sharing_off')), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('help_others_too_note'.i18n), findsNothing);
  });

  testWidgets('the friends sheet says who else is helped under the friends '
      'card', (tester) async {
    final helpers = _Helpers(_helping());
    await _pump(tester, helpers, const HelpingFriendsSheet(), sharing: true);
    final line = find.byKey(const Key('helping.scope'));
    expect(
      tester.widget<Text>(line).data,
      '${'helping_scope_line_all'.i18n} · ',
    );
    expect(find.text('helping_scope_change'.i18n), findsOneWidget);
    expect(
      tester.getTopLeft(line).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('helping.paste_another'))).dy,
      ),
    );
    expect(
      tester.getBottomLeft(line).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('helping.data_relayed'))).dy,
      ),
    );

    helpers.state = helpers.state.copyWith(helpOthers: false);
    await tester.pump();
    expect(
      tester.widget<Text>(line).data,
      '${'helping_scope_line_friends'.i18n} · ',
    );
  });

  testWidgets('the friends sheet shows a scope still being saved, as Action '
      'Mode does', (tester) async {
    final helpers = _Helpers(
      _helping().copyWith(helpOthers: true, requestedHelpOthers: false),
    );
    await _pump(tester, helpers, const HelpingFriendsSheet(), sharing: true);
    expect(
      tester.widget<Text>(find.byKey(const Key('helping.scope'))).data,
      '${'helping_scope_line_friends'.i18n} · ',
    );
  });

  testWidgets('Change swaps the friends sheet for Who you\'re helping, '
      'not a second sheet on top', (tester) async {
    final helpers = _Helpers(_helping());
    await _pump(
      tester,
      helpers,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showHelpingFriendsSheet(context),
          child: const Text('open'),
        ),
      ),
      sharing: true,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpingFriendsSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('helping.scope.change')));
    await tester.pumpAndSettle();
    expect(find.byType(HelpingFriendsSheet), findsNothing);
    expect(find.byType(WhoYoureHelpingSheet), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('helping.scope.friends')),
        matching: find.text('Only my Personal Proxy connections'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Settings\' Who you\'re helping row says whom and opens the '
      'sheet', (tester) async {
    final helpers = _Helpers(_helping().copyWith(helpOthers: false));
    await _pump(tester, helpers, const WhoYoureHelpingTile());
    final row = find.byKey(const Key('helping.scope.row'));
    expect(
      find.descendant(
        of: row,
        matching: find.text('helping_scope_only_friends'.i18n),
      ),
      findsOneWidget,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(WhoYoureHelpingSheet), findsOneWidget);
  });

  testWidgets('Who you\'re helping: a choice reversed while the first is '
      'still being saved is written too', (tester) async {
    final pending = <Completer<void>>[];
    final helpers = _Helpers(_helping())..helpOthersPending = pending;
    await _pump(tester, helpers, const WhoYoureHelpingSheet());
    await tester.tap(find.byKey(const Key('helping.scope.friends')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('helping.scope.all')));
    await tester.pump();
    expect(helpers.helpOthers, [false, true]);
    for (final write in pending) {
      write.complete();
    }
    await tester.pump();
  });

  testWidgets('Who you\'re helping: an older write finishing does not '
      'forget a newer choice', (tester) async {
    final pending = <Completer<void>>[];
    final helpers = _Helpers(_helping().copyWith(helpOthers: false))
      ..helpOthersPending = pending;
    await _pump(tester, helpers, const WhoYoureHelpingSheet());
    final friends = find.byKey(const Key('helping.scope.friends'));
    final all = find.byKey(const Key('helping.scope.all'));
    // All, Friends, All, all still being written.
    for (final row in [all, friends, all]) {
      await tester.tap(row);
      await tester.pump();
    }
    expect(helpers.helpOthers, [true, false, true]);
    // The first two finish; the last All is still being written.
    pending[0].complete();
    pending[1].complete();
    await tester.pump();
    await tester.tap(friends);
    await tester.pump();
    expect(helpers.helpOthers, [
      true,
      false,
      true,
      false,
    ], reason: 'Only my friends, chosen last, must be written');
    for (final write in pending.skip(2)) {
      write.complete();
    }
    await tester.pump();
  });

  testWidgets('Who you\'re helping: a choice still being saved survives '
      'closing and reopening the sheet', (tester) async {
    final pending = <Completer<void>>[];
    final helpers = _Helpers(_helping().copyWith(helpOthers: false))
      ..helpOthersPending = pending;
    final show = ValueNotifier(true);
    await _pump(
      tester,
      helpers,
      ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (_, on, _) =>
            on ? const WhoYoureHelpingSheet() : const SizedBox(),
      ),
    );
    final friends = find.byKey(const Key('helping.scope.friends'));
    final all = find.byKey(const Key('helping.scope.all'));
    await tester.tap(all);
    await tester.pump();
    expect(helpers.helpOthers, [true]);
    show.value = false;
    await tester.pump();
    show.value = true;
    await tester.pump();
    bool? radio(Finder row) => tester
        .widget<AppRadioButton<bool>>(
          find.descendant(of: row, matching: find.byType(AppRadioButton<bool>)),
        )
        .groupValue;
    expect(radio(all), isTrue, reason: 'All countries is being saved');
    await tester.tap(friends);
    await tester.pump();
    expect(helpers.helpOthers, [
      true,
      false,
    ], reason: 'Only my friends, chosen last, must be written');
    for (final write in pending) {
      write.complete();
    }
    await tester.pump();
    expect(helpers.state.requestedHelpOthers, isNull);
  });

  testWidgets('Who you\'re helping: Only my friends first, then All '
      'countries; each drives help-others', (tester) async {
    final helpers = _Helpers(_helping());
    await _pump(tester, helpers, const WhoYoureHelpingSheet());
    final friends = find.byKey(const Key('helping.scope.friends'));
    final all = find.byKey(const Key('helping.scope.all'));
    expect(
      find.descendant(
        of: friends,
        matching: find.text('helping_scope_only_friends'.i18n),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: all,
        matching: find.text('helping_scope_all_countries'.i18n),
      ),
      findsOneWidget,
    );
    expect(tester.getTopLeft(friends).dy, lessThan(tester.getTopLeft(all).dy));
    bool? radio(Finder row) => tester
        .widget<AppRadioButton<bool>>(
          find.descendant(of: row, matching: find.byType(AppRadioButton<bool>)),
        )
        .groupValue;
    expect(radio(all), isTrue, reason: 'All countries is the default');

    // Choosing what is already chosen writes nothing.
    await tester.tap(all);
    await tester.pump();
    expect(helpers.helpOthers, isEmpty);

    await tester.tap(friends);
    await tester.pump();
    expect(helpers.helpOthers, [false]);

    helpers.state = helpers.state.copyWith(helpOthers: false);
    await tester.pump();
    await tester.tap(all);
    await tester.pump();
    expect(helpers.helpOthers, [false, true]);
  });

  testWidgets('the friends sheet shows Connected and Not connected once '
      'known, and a friend not connected stays enabled', (tester) async {
    final helpers = _Helpers(
      _helping(
        helping: const [
          HelperPairingView(pairingId: 'p1', name: 'Sara', connected: true),
          HelperPairingView(pairingId: 'p2', name: 'Reza', connected: false),
        ],
      ),
    );
    await _pump(tester, helpers, const HelpingFriendsSheet(), sharing: true);
    expect(
      tester.widget<Text>(find.byKey(const Key('helping.status.p1'))).data,
      'helping_connected'.i18n,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('helping.status.p2'))).data,
      'helping_not_connected'.i18n,
    );
    final reza = tester.widget<ListTile>(
      find.descendant(
        of: find.byKey(const Key('helping.friend.p2')),
        matching: find.byType(ListTile),
        matchRoot: true,
      ),
    );
    expect(reza.enabled, isTrue);
  });

  testWidgets('the sheet title says how many are connected only once known', (
    tester,
  ) async {
    Future<void> open(HelpersState state) async {
      await _pump(
        tester,
        _Helpers(state),
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showHelpingFriendsSheet(context),
            child: const Text('open'),
          ),
        ),
        sharing: true,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    await open(_helping());
    expect(find.text('helping_sheet_title'.i18n), findsOneWidget);
    expect(find.byKey(const Key('helping.sheet.connected')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await open(
      _helping(
        helping: const [
          HelperPairingView(pairingId: 'p1', name: 'Sara', connected: true),
        ],
      ),
    );
    expect(
      find.text('helping_connected_named'.i18n.fill(['Sara'])),
      findsOneWidget,
    );
  });

  testWidgets('the card refreshes every minute while shown, and stops when '
      'gone', (tester) async {
    final helpers = _Helpers(_helping());
    final show = ValueNotifier(true);
    await _pump(
      tester,
      helpers,
      ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (_, visible, _) => visible
            ? const PersonalProxyConnectionsCard()
            : const SizedBox.shrink(),
      ),
      sharing: true,
    );
    expect(helpers.refreshes, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(PersonalProxyConnectionsCard.refreshInterval);
    expect(helpers.refreshes, 1);
    await tester.pump(PersonalProxyConnectionsCard.refreshInterval);
    expect(helpers.refreshes, 2);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(PersonalProxyConnectionsCard.refreshInterval);
    expect(helpers.refreshes, 2, reason: 'not while the app is in the back');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(PersonalProxyConnectionsCard.refreshInterval);
    expect(helpers.refreshes, 3);

    show.value = false;
    await tester.pump();
    await tester.pump(PersonalProxyConnectionsCard.refreshInterval * 3);
    expect(helpers.refreshes, 3, reason: 'the timer goes with the card');
  });

  testWidgets('Paste another invite link opens the paste form in new-invite '
      'mode', (tester) async {
    await sl.reset();
    final router = _Router();
    sl.registerSingleton<AppRouter>(router);
    addTearDown(sl.reset);
    await _pump(
      tester,
      _Helpers(_helping()),
      Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: HelpingFriendsSheet()),
        ),
      ),
      sharing: true,
    );
    await tester.tap(find.byKey(const Key('helping.paste_another')));
    await tester.pump();
    final route = router.pushed.single;
    expect(route.routeName, routes.HelpFriend.name);
    expect((route.args! as HelpFriendArgs).newInvite, isTrue);
  });

  testWidgets('in new-invite mode a waiting claim does not take over: the '
      'paste form shows', (tester) async {
    final helpers = _Helpers(
      const HelpersState(
        view: HelpersView(
          unlocked: true,
          helping: [_sara],
          claims: [
            HelperClaimView(id: 'c1', code: '2562', expiresUnix: _future),
          ],
        ),
      ),
    );
    await _pump(tester, helpers, const HelpFriend(newInvite: true));
    await tester.pump();
    expect(find.byKey(const Key('help_friend.code')), findsNothing);
    expect(find.byKey(const Key('help_friend.link')), findsOneWidget);
    expect(find.byKey(const Key('help_friend.form')), findsOneWidget);
  });

  testWidgets('the sheet warns when sharing is off', (tester) async {
    await _pump(tester, _Helpers(_helping()), const HelpingFriendsSheet());
    expect(find.byKey(const Key('helping.sharing_off')), findsOneWidget);
  });

  testWidgets('removing a friend asks first, then ends the pairing even when '
      'the sheet is gone before the dialog callback runs', (tester) async {
    final helpers = _Helpers(_helping());
    final show = ValueNotifier(true);
    await _pump(
      tester,
      helpers,
      ValueListenableBuilder<bool>(
        valueListenable: show,
        builder: (_, visible, _) =>
            visible ? const HelpingFriendsSheet() : const SizedBox.shrink(),
      ),
      sharing: true,
    );
    await tester.tap(find.byKey(const Key('helping.remove.p1')));
    await tester.pumpAndSettle();
    expect(
      find.text('helping_remove_confirm'.i18n.fill(['Sara'])),
      findsOneWidget,
    );
    expect(helpers.ended, isEmpty);
    await tester.tap(find.widgetWithText(PrimaryButton, 'helping_remove'.i18n));
    await tester.pump();
    show.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(helpers.ended, ['p1']);
  });

  test('helpingHoursMinutes', () {
    expect(helpingHoursMinutes(3 * 3600 + 20 * 60), (3, 20));
    expect(helpingHoursMinutes(3600), (1, 0));
    expect(helpingHoursMinutes(59), (0, 0));
    expect(helpingHoursMinutes(0), (0, 0));
  });

  group('helper invite deep links', () {
    test('are recognized', () {
      for (final u in [
        'https://lantern.io/help#abc',
        'https://lantern.io/help/#abc',
        'https://www.lantern.io/help#abc',
        '${AppBuildInfo.appAuthScheme}://help#abc',
      ]) {
        expect(isHelperInviteUri(Uri.parse(u)), isTrue, reason: u);
      }
      for (final u in [
        'https://lantern.io/helpx#abc',
        'https://evil.io/help#abc',
        'http://lantern.io/help#abc',
        'https://lantern.io/affiliate/x',
        '${AppBuildInfo.appAuthScheme}://affiliate',
      ]) {
        expect(isHelperInviteUri(Uri.parse(u)), isFalse, reason: u);
      }
    });

    test('normalize to the canonical link', () {
      expect(
        helperInviteLink(
          Uri.parse('${AppBuildInfo.appAuthScheme}://help#SECRET'),
        ),
        'https://lantern.io/help/#SECRET',
      );
      expect(
        helperInviteLink(Uri.parse('https://www.lantern.io/help#SECRET')),
        'https://lantern.io/help/#SECRET',
      );
    });

    test('pasted links normalize like deep links', () {
      for (final u in [
        'https://lantern.io/help/#SECRET',
        'https://lantern.io/help#SECRET',
        '  https://www.lantern.io/help#SECRET\n',
        '${AppBuildInfo.appAuthScheme}://help#SECRET',
      ]) {
        expect(
          normalizeHelperInviteInput(u),
          'https://lantern.io/help/#SECRET',
          reason: u,
        );
      }
      expect(normalizeHelperInviteInput(' not a link '), 'not a link');
      for (final u in [
        'Sara wants your help staying online. https://lantern.io/help/#SECRET',
        'HTTPS://LANTERN.IO/help#SECRET',
      ]) {
        expect(
          normalizeHelperInviteInput(u),
          'https://lantern.io/help/#SECRET',
          reason: u,
        );
      }
      expect(
        normalizeHelperInviteInput('https://evil.example/help#SECRET'),
        'https://evil.example/help#SECRET',
      );
    });

    test('trailing sentence punctuation is not part of the secret', () {
      for (final u in [
        'https://lantern.io/help/#SECRET.',
        'Join me: https://lantern.io/help/#SECRET!',
        '(https://lantern.io/help/#SECRET),',
        '"https://lantern.io/help#SECRET"',
      ]) {
        expect(
          normalizeHelperInviteInput(u),
          'https://lantern.io/help/#SECRET',
          reason: u,
        );
      }
    });

    test('a help link without a secret does not hide a later invite', () {
      expect(
        normalizeHelperInviteInput(
          'See https://lantern.io/help then https://lantern.io/help/#SECRET',
        ),
        'https://lantern.io/help/#SECRET',
      );
    });
  });
}
