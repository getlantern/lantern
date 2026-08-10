import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';

import 'app_robot.dart';

/// Payment feature robot. Selects a plan through [plansProvider] — the
/// source of truth — and drives the payment-method screen through the UI.
class PaymentRobot {
  PaymentRobot(this.tester, this.app);

  final WidgetTester tester;
  final AppRobot app;

  final Finder stripeProvider = find.byKey(
    const Key('payment.provider.stripe'),
  );
  final Finder stripeCheckoutButton = find.byKey(
    const Key('payment.checkout.stripe'),
  );

  ProviderContainer? _cachedContainer;

  /// Root [ProviderContainer], resolved once from a mounted home element and
  /// cached; it outlives route changes so later reads are route-independent.
  ProviderContainer get container {
    final cached = _cachedContainer;
    if (cached != null) {
      return cached;
    }
    final elements = app.homeScreen.evaluate();
    if (elements.isEmpty) {
      fail('Cannot resolve providers: home screen is not mounted');
    }
    return _cachedContainer = ProviderScope.containerOf(
      elements.first,
      listen: false,
    );
  }

  /// Loads plans from the backend, keeping the provider alive for the rest
  /// of the test.
  Future<PlansData> loadPlans({
    Duration timeout = const Duration(seconds: 60),
  }) {
    final subscription = container.listen(plansProvider, (_, _) {});
    addTearDown(subscription.close);
    return container.read(plansProvider.future).timeout(timeout);
  }

  /// Selects the best-value plan (falling back to the first) and returns it.
  Plan selectBestValuePlan(PlansData plans) {
    final plan = plans.plans.firstWhere(
      (plan) => plan.bestValue,
      orElse: () => plans.plans.first,
    );
    container.read(plansProvider.notifier).setSelectedPlan(plan);
    e2eLog('Selected plan ${plan.id}');
    return plan;
  }

  /// Jumps straight to the payment-method screen for [email], replacing the
  /// whole stack — checkout smokes verify rendering, not navigation.
  Future<void> openPaymentMethods({
    required String email,
    required AuthFlow authFlow,
  }) {
    return appRouter.replaceAll([
      ChoosePaymentMethod(email: email, authFlow: authFlow),
    ]);
  }

  /// Expands the Stripe method if collapsed and taps its checkout button.
  /// The tap is not settled: it opens a WebView with a loading spinner and
  /// pumpAndSettle would hang on the animation.
  Future<void> startStripeCheckout() async {
    await app.waitForControlReady(
      stripeProvider,
      controlName: 'Stripe payment method',
    );
    if (stripeCheckoutButton.evaluate().isEmpty) {
      e2eLog('Expanding the Stripe payment method');
      await tester.tap(stripeProvider);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await app.waitForControlReady(
      stripeCheckoutButton,
      controlName: 'Stripe checkout button',
    );
    e2eLog('Tapping the Stripe checkout button');
    await tester.ensureVisible(stripeCheckoutButton);
    await tester.tap(stripeCheckoutButton);
  }
}

/// Unique throwaway address for checkout smokes: `e2e+<uuid>@getlantern.org`.
String e2eEmail() => 'e2e+${_newUuid()}@getlantern.org';

String _newUuid() {
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
