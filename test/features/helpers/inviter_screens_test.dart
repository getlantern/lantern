import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
// common.dart re-exports the generated route classes, which share the
// screens' names.
import 'package:lantern/core/common/common.dart' hide GetHelp, InviteShare;
import 'package:lantern/features/helpers/approve_helper_sheet.dart';
import 'package:lantern/features/helpers/get_help.dart';
import 'package:lantern/features/helpers/invite_share.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';

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
}

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

  testWidgets('the invite screen says when the invite is gone', (tester) async {
    final fake = _Helpers(const HelpersState());
    await _pump(tester, fake, const InviteShare(inviteId: 'nope'));
    expect(find.byKey(const Key('invite.gone')), findsOneWidget);
  });
}
