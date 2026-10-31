import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// common.dart re-exports the generated route classes, which share the
// screens' names.
import 'package:lantern/core/common/common.dart' hide HelpFriend;
import 'package:lantern/core/common/common.dart' as routes show HelpFriend;
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/utils/deeplink_utils.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/helpers/help_friend.dart';
import 'package:lantern/features/helpers/helper_errors.dart';
import 'package:lantern/features/helpers/helping_friends.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

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
  @override
  Future<void> setHelpOthers(bool value) async => helpOthers.add(value);
  @override
  Future<HelperResult> claim(String link, String name) async {
    claims.add((link, name));
    final i = claims.length - 1;
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

  void approve(HelpersView view) => state = state.copyWith(
    view: view,
    helpingApprovals: state.helpingApprovals + 1,
  );

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
}

class _Share extends ShareNotifier {
  _Share({this.active = false});
  final bool active;
  @override
  ShareState build() => ShareState(active: active);
  @override
  Future<bool> ensureConsent(BuildContext context) async => true;
}

Future<void> _pump(
  WidgetTester tester,
  _Helpers helpers,
  Widget child, {
  bool sharing = false,
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
        shareProvider.overrideWith(() => _Share(active: sharing)),
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
      find.text('help_friend_approved'.i18n.fill(['Reza'])),
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
    expect(find.byKey(const Key('help_friend.link')), findsOneWidget);
    await _claim(tester);
    expect(
      tester.widget<Text>(find.byKey(const Key('help_friend.link_error'))).data,
      helperErrorText('bad_link'),
    );
    expect(find.byKey(const Key('help_friend.error')), findsNothing);
    await tester.enterText(find.byKey(const Key('help_friend.link')), _link);
    await tester.pump();
    expect(find.byKey(const Key('help_friend.link_error')), findsNothing);
    await tester.tap(find.byKey(const Key('help_friend.accept')));
    await tester.pump();
    await tester.pump();
    expect(helpers.claims.last, (_link, 'Ali'));
    expect(find.text('2562'), findsOneWidget);
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
    expect(find.text('help_friend_link_hint'.i18n), findsOneWidget);

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

  testWidgets('opening HelpFriend refreshes only if used, fills in the held '
      'link, and caps the name at 60', (tester) async {
    final helpers = _Helpers(const HelpersState());
    helpers.holdLink(_link);
    await _pump(tester, helpers, const HelpFriend(fromLink: true));
    expect(helpers.refreshes, 1);
    // The link was taken once, and fills the field.
    expect(helpers.takeLink(), isNull);
    final link = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('help_friend.link')),
        matching: find.byType(TextField),
      ),
    );
    expect(link.controller!.text, _link);
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
      'help_friend_link_hint'.i18n,
      'help_friend_name_label'.i18n,
      'help_friend_name_hint'.i18n,
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
      find.text('help_friend_approved'.i18n.fill(['Sara'])),
      findsOneWidget,
    );
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
      find.text('help_friend_approved'.i18n.fill(['Reza'])),
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
      find.text('help_friend_approved'.i18n.fill(['helping_unnamed'.i18n])),
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

  testWidgets('the friends sheet: rows, paste another, data relayed, and '
      'help others too', (tester) async {
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
    await tester.tap(find.byKey(const Key('helping.help_others_switch')));
    await tester.pump();
    expect(helpers.helpOthers, [false]);
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
