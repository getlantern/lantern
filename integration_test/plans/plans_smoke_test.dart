import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/common.dart' show appRouter, isStoreVersion;
import 'package:lantern/core/extensions/plan.dart';
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/features/plans/plan_item.dart';
import 'package:lantern/main.dart' as app;

import '../utils/app_robot.dart';

final _plansCta = find.byKey(const Key('plans.cta'));
final _restoreLink = find.byKey(const Key('plans.restore'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerPlansSmokeTests();
}

/// Exposed so an aggregator entrypoint (android_all_e2e_test.dart) can
/// register this suite alongside others.
///
/// The whole suite soft-skips when the signed-in account is already Pro —
/// the upgrade entry point doesn't exist then.
void registerPlansSmokeTests() {
  group('Plans smoke test', () {
    testWidgets('plans load with prices and one best value', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      if (!await appRobot.openPlansIfFree()) {
        return _skipProAccount(tester);
      }
      try {
        final items = tester
            .widgetList<PlanItem>(find.byType(PlanItem))
            .toList();
        expect(items, isNotEmpty, reason: 'No plan cards rendered');
        for (final item in items) {
          expect(
            item.plan.formattedYearlyPrice,
            isNotEmpty,
            reason: 'Plan ${item.plan.id} has no formatted price',
          );
        }
        // PlansListView does firstWhere(bestValue) — zero would crash the
        // screen, more than one makes the badge ambiguous.
        expect(
          items.where((item) => item.plan.bestValue).length,
          1,
          reason: 'Expected exactly one best-value plan',
        );

        final bestValue = items.singleWhere((item) => item.plan.bestValue);
        expect(
          find.descendant(
            of: find.byKey(Key('plans.item.${bestValue.plan.id}')),
            matching: find.text('best_value'.i18n),
          ),
          findsOneWidget,
          reason: 'Best Value badge not shown on plan ${bestValue.plan.id}',
        );

        expect(_plansCta, findsOneWidget);
      } finally {
        await _resetToRoot(tester);
      }
    });

    testWidgets('tapping a plan moves the selection', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      if (!await appRobot.openPlansIfFree()) {
        return _skipProAccount(tester);
      }
      try {
        final items = tester
            .widgetList<PlanItem>(find.byType(PlanItem))
            .toList();
        if (items.length < 2) {
          debugPrint('SKIP: only ${items.length} plan(s), nothing to switch');
          return;
        }
        final unselected = items.firstWhere((item) => !item.planSelected).plan;

        final card = find.byKey(Key('plans.item.${unselected.id}'));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<PlanItem>(find.byKey(Key('plans.item.${unselected.id}')))
              .planSelected,
          isTrue,
          reason: 'Tapped plan ${unselected.id} did not become selected',
        );
      } finally {
        await _resetToRoot(tester);
      }
    });

    testWidgets('catalog matches the build type', (tester) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      if (!await appRobot.openPlansIfFree()) {
        return _skipProAccount(tester);
      }
      try {
        // The restore-purchase link is the store-mode marker: present on
        // store builds (StoreKit/Play), absent on sideload/desktop.
        expect(
          _restoreLink,
          isStoreVersion() ? findsOneWidget : findsNothing,
          reason:
              'Restore-purchase link does not match '
              'isStoreVersion()=${isStoreVersion()}',
        );
      } finally {
        await _resetToRoot(tester);
      }
    });

    testWidgets('CTA leads to checkout without billing (non-store)', (
      tester,
    ) async {
      await app.main();
      final appRobot = AppRobot(tester);
      await appRobot.waitForHomeReady();
      if (isStoreVersion()) {
        // On store builds the CTA opens real StoreKit/Play Billing UI —
        // never tap it here; the previous test already asserted it exists.
        debugPrint('SKIP: store build, not tapping the purchase CTA');
        return;
      }
      if (!await appRobot.openPlansIfFree()) {
        return _skipProAccount(tester);
      }
      try {
        await tester.ensureVisible(_plansCta);
        await tester.tap(_plansCta);
        await tester.pump();

        // Non-store: signed-out users land on sign-up, signed-in ones on
        // ChoosePaymentMethod. Both stop short of any payment SDK.
        await _waitForAny(tester, {
          'sign-up email screen': find.byKey(AuthKeys.signUpEmailField),
          'payment methods list': find.byKey(const Key('choose_payment.list')),
        });
      } finally {
        await _resetToRoot(tester);
      }
    });
  });
}

void _skipProAccount(WidgetTester tester) {
  debugPrint('SKIP: account is Pro, no upgrade entry point');
}

/// Waits until any of [finders] appears; fails naming what never showed up.
Future<void> _waitForAny(
  WidgetTester tester,
  Map<String, Finder> finders, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    for (final finder in finders.values) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  fail('None of ${finders.keys.join(', ')} appeared within $timeout');
}

Future<void> _resetToRoot(WidgetTester tester) async {
  appRouter.popUntilRoot();
  await tester.pumpAndSettle();
}
