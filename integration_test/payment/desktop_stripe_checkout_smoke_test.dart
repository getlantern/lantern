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
import 'package:lantern/lantern_app.dart';
import 'package:lantern/main.dart' as app;

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
      await _waitFor(
        tester,
        () => find.byType(LanternApp).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
        failure: () => 'Lantern did not render its Flutter UI',
      );

      final appElement = find.byType(LanternApp).evaluate().first;
      final container = ProviderScope.containerOf(appElement, listen: false);
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

      final observer = _StripeCheckoutObserver();
      await appRouter.replaceAll([
        ChoosePaymentMethod(
          email: 'e2e+${_newUuid()}@getlantern.org',
          authFlow: AuthFlow.renewSubscription,
          checkoutObserver: observer,
        ),
      ]);

      final stripeProvider = find.byKey(const Key('payment.provider.stripe'));
      await _waitFor(
        tester,
        () => stripeProvider.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
        failure: () => 'Stripe was not shown on the payment-method screen',
      );

      final checkoutButton = find.byKey(const Key('payment.checkout.stripe'));
      if (checkoutButton.evaluate().isEmpty) {
        await tester.tap(stripeProvider);
        await tester.pump(const Duration(milliseconds: 300));
      }
      await _waitFor(
        tester,
        () => checkoutButton.evaluate().isNotEmpty,
        timeout: const Duration(seconds: 10),
        failure: () => 'Stripe checkout button was not available',
      );

      await tester.ensureVisible(checkoutButton);
      await tester.tap(checkoutButton);

      await _waitFor(
        tester,
        () => observer.finished,
        timeout: const Duration(minutes: 3),
        failure: () => observer.failureMessage,
      );

      if (observer.checkoutFailure != null) {
        fail('Stripe Checkout failed to load: ${observer.checkoutFailure}');
      }
      expect(find.byKey(const ValueKey('app-webview')), findsOneWidget);
      expect(observer.uri?.host, _stripeHost);
      expect(observer.documentLength, greaterThan(0));
      await _captureMacOSCheckoutScreenshot(tester);
      debugPrint(
        'Stripe Checkout rendered from $_stripeHost '
        '(${observer.documentLength} document characters)',
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
  debugPrint('Timed out waiting for the macOS checkout screenshot');
}

Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  required Duration timeout,
  required String Function() failure,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (condition()) return;
  }
  fail(failure());
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

class _StripeCheckoutObserver implements AppWebViewObserver {
  Uri? uri;
  int documentLength = 0;
  String? lastFailure;
  String? checkoutFailure;

  bool get finished => uri?.host == _stripeHost || checkoutFailure != null;

  String get failureMessage => lastFailure == null
      ? 'Stripe Checkout did not load a non-empty document'
      : 'Stripe Checkout did not load: $lastFailure';

  @override
  void onPageLoaded(Uri uri, {required int documentLength}) {
    if (uri.host != _stripeHost) return;
    this.uri = uri;
    this.documentLength = documentLength;
  }

  @override
  void onPageLoadFailed(Uri? uri, String reason) {
    lastFailure = '${uri?.host ?? 'unknown host'}: $reason';
    if (uri?.host == _stripeHost) {
      checkoutFailure = reason;
    }
  }
}
