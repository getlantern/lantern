import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/widgets/app_webview.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';

import 'app_robot.dart';

/// Drives plan selection and the payment-method screen through the same state
/// and controls used by the app.
class PaymentRobot {
  PaymentRobot(this.tester, this.app);

  final WidgetTester tester;
  final AppRobot app;

  ProviderContainer? _cachedContainer;

  /// Resolves and caches the root provider container before route changes.
  ProviderContainer get container {
    final cached = _cachedContainer;
    if (cached != null) return cached;

    final elements = app.homeScreen.evaluate();
    if (elements.isEmpty) {
      fail('Cannot resolve providers: home screen is not mounted');
    }
    return _cachedContainer = ProviderScope.containerOf(
      elements.first,
      listen: false,
    );
  }

  /// Loads plans while keeping the auto-disposed provider alive for the test.
  Future<PlansData> loadPlans({
    Duration timeout = const Duration(seconds: 60),
  }) {
    final subscription = container.listen(plansProvider, (_, _) {});
    addTearDown(subscription.close);
    return container.read(plansProvider.future).timeout(timeout);
  }

  /// Selects the best-value plan, falling back to the first available plan.
  Plan selectBestValuePlan(PlansData plans) {
    final plan = plans.plans.firstWhere(
      (plan) => plan.bestValue,
      orElse: () => plans.plans.first,
    );
    container.read(plansProvider.notifier).setSelectedPlan(plan);
    e2eLog('Selected plan ${plan.id}');
    return plan;
  }

  /// Opens the payment-method screen directly for a checkout smoke test.
  Future<void> openPaymentMethods({
    required String email,
    required AuthFlow authFlow,
    AppWebViewObserver? checkoutObserver,
  }) {
    return appRouter.replaceAll([
      ChoosePaymentMethod(
        email: email,
        authFlow: authFlow,
        checkoutObserver: checkoutObserver,
      ),
    ]);
  }

  /// Expands [provider] when needed and starts its checkout flow.
  Future<void> startCheckout({required String provider}) async {
    final providerTile = find.byKey(Key('payment.provider.$provider'));
    final checkoutButton = find.byKey(Key('payment.checkout.$provider'));

    await app.waitForControlReady(
      providerTile,
      controlName: '$provider payment method',
      onboardingGrace: Duration.zero,
    );
    if (checkoutButton.evaluate().isEmpty) {
      e2eLog('Expanding the $provider payment method');
      await tester.tap(providerTile);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await app.waitForControlReady(
      checkoutButton,
      controlName: '$provider checkout button',
      onboardingGrace: Duration.zero,
    );

    e2eLog('Starting $provider checkout');
    await tester.ensureVisible(checkoutButton);
    await tester.tap(checkoutButton);
  }
}

String e2eEmail([String? runID]) =>
    'e2e+${runID ?? newE2ERunID()}@getlantern.org';

String newE2ERunID() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
