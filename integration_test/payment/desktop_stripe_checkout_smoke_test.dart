import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/core/widgets/app_webview.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/main.dart' as app;

import '../utils/app_robot.dart';
import '../utils/widget_wait_utils.dart';

const _stripeHost = 'checkout.stripe.com';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'staging Stripe Checkout renders in the desktop WebView',
    (tester) async {
      expect(
        Platform.isWindows || Platform.isMacOS,
        isTrue,
        reason: 'This smoke runs on Windows and macOS',
      );

      await app.main();
      final robot = AppRobot(tester);
      await robot.waitForHomeReady();

      final container = ProviderScope.containerOf(
        tester.element(robot.homeScreen),
        listen: false,
      );
      final plansSubscription = container.listen(plansProvider, (_, _) {});
      addTearDown(plansSubscription.close);

      final plans = await container
          .read(plansProvider.future)
          .timeout(const Duration(seconds: 60));
      final stripe = plans.providers.desktop.where(
        (provider) => provider.providers.name == 'stripe',
      );
      expect(stripe, isNotEmpty, reason: 'Staging did not return Stripe');
      expect(
        stripe.first.providers.supportSubscription,
        isTrue,
        reason: 'Staging Stripe must support subscriptions',
      );
      expect(plans.plans, isNotEmpty, reason: 'Staging returned no plans');

      final selectedPlan = plans.plans.firstWhere(
        (plan) => plan.bestValue,
        orElse: () => plans.plans.first,
      );
      container.read(plansProvider.notifier).setSelectedPlan(selectedPlan);
      e2eLog('Selected plan ${selectedPlan.id}');

      final checkout = _StripeCheckoutTracker();
      final pageEventSubscription = container.listen(webViewPageEventProvider, (
        _,
        event,
      ) {
        if (event != null) checkout.add(event);
      });
      addTearDown(pageEventSubscription.close);

      await appRouter.replaceAll([
        ChoosePaymentMethod(
          email: 'e2e+${_newUuid()}@getlantern.org',
          authFlow: AuthFlow.renewSubscription,
        ),
      ]);

      final stripeProvider = find.byKey(const Key('payment.provider.stripe'));
      await WidgetWaitUtils.waitForCondition(
        tester,
        () => stripeProvider.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
        describeFailure: () =>
            'Stripe was not shown on the payment-method screen. '
            'Visible keys: ${robot.visibleKeys().join(', ')}',
      );

      final checkoutButton = find.byKey(const Key('payment.checkout.stripe'));
      if (checkoutButton.evaluate().isEmpty) {
        e2eLog('Expanding the Stripe payment method');
        await tester.tap(stripeProvider);
        await tester.pump(const Duration(milliseconds: 300));
      }
      await WidgetWaitUtils.waitForCondition(
        tester,
        () => checkoutButton.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 10),
        describeFailure: () =>
            'Stripe checkout button was not available. '
            'Visible keys: ${robot.visibleKeys().join(', ')}',
      );

      // Tapped directly (not via robot.tap): the tap opens the WebView with
      // its loading spinner, and pumpAndSettle would hang on the animation.
      e2eLog('Tapping the Stripe checkout button');
      await tester.ensureVisible(checkoutButton);
      await tester.tap(checkoutButton);

      await WidgetWaitUtils.waitForCondition(
        tester,
        () => checkout.finished,
        timeout: const Duration(minutes: 3),
        describeFailure: () => checkout.failureMessage,
      );

      if (checkout.failure != null) {
        fail('Stripe Checkout failed to load: ${checkout.failure}');
      }
      expect(find.byKey(const ValueKey('app-webview')), findsOneWidget);
      expect(checkout.uri?.host, _stripeHost);
      expect(checkout.documentLength, greaterThan(0));
      await _captureMacOSCheckoutScreenshot(tester);
      e2eLog(
        'Stripe Checkout rendered from $_stripeHost '
        '(${checkout.documentLength} document characters)',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _captureMacOSCheckoutScreenshot(WidgetTester tester) async {
  if (!Platform.isMacOS) return;

  final directory = await AppStorageUtils.getAppDirectory();
  final ready = File('${directory.path}/.checkout-screenshot-ready');
  final captured = File('${directory.path}/.checkout-screenshot-captured');
  await ready.create(recursive: true);
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (await captured.exists()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  e2eLog('Timed out waiting for the macOS checkout screenshot');
}

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

/// Folds [webViewPageEventProvider] events into a checkout verdict.
class _StripeCheckoutTracker {
  Uri? uri;
  int documentLength = 0;
  String? lastFailure;
  String? _terminalFailure;

  bool get loaded => uri?.host == _stripeHost;

  bool get finished => loaded || _terminalFailure != null;

  /// Non-null once checkout can no longer succeed.
  String? get failure => _terminalFailure;

  String get failureMessage => lastFailure == null
      ? 'Stripe Checkout did not load a non-empty document'
      : 'Stripe Checkout did not load: $lastFailure';

  void add(WebViewPageEvent event) {
    switch (event) {
      case WebViewPageLoaded(:final uri, :final documentLength):
        if (uri?.host != _stripeHost) return;
        this.uri = uri;
        this.documentLength = documentLength;
      case WebViewPageLoadFailed(:final uri, :final reason):
        lastFailure = '${uri?.host ?? 'unknown host'}: $reason';
        // A main-frame failure anywhere in the redirect chain is terminal
        // for the smoke — don't wait out the full timeout. Cancellation
        // errors fire during normal redirects, so they only count on the
        // Stripe host itself.
        if (uri?.host == _stripeHost || !_isCancellation(reason)) {
          _terminalFailure = lastFailure;
        }
    }
  }

  static bool _isCancellation(String reason) {
    final lower = reason.toLowerCase();
    return lower.contains('cancel') || lower.contains('abort');
  }
}
