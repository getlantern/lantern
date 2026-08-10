import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_webview.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/main.dart' as app;

import '../utils/app_robot.dart';
import '../utils/widget_wait_utils.dart';

const _stripeHost = 'checkout.stripe.com';
const _screenshotPath = String.fromEnvironment('PAYMENT_SMOKE_SCREENSHOT_PATH');
const _screenshotRenderTimeout = Duration(seconds: 30);
const _screenshotPollInterval = Duration(milliseconds: 250);
const _minimumScreenshotContrast = 64;
const _darkPixelLuminance = 192;

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
        if (event != null) unawaited(checkout.add(event));
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
      if (Platform.isMacOS) {
        final screenshot = checkout.screenshot;
        if (screenshot == null) {
          fail('The Stripe WebView did not return a screenshot');
        }
        if (_screenshotPath.isNotEmpty) {
          final file = File(_screenshotPath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(screenshot, flush: true);
          e2eLog('Stripe Checkout screenshot saved to ${file.path}');
        }
      }
      e2eLog(
        'Stripe Checkout rendered from $_stripeHost '
        '(${checkout.documentLength} document characters)',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<Uint8List> _waitForRenderedScreenshot(
  Future<Uint8List?> Function() captureScreenshot,
) async {
  final deadline = DateTime.now().add(_screenshotRenderTimeout);
  Object? lastError;
  while (DateTime.now().isBefore(deadline)) {
    try {
      final screenshot = await captureScreenshot().timeout(
        const Duration(seconds: 5),
      );
      if (screenshot != null && await _hasVisibleContent(screenshot)) {
        return screenshot;
      }
    } catch (error) {
      lastError = error;
    }
    await Future<void>.delayed(_screenshotPollInterval);
  }
  final detail = lastError == null ? '' : ': $lastError';
  throw TimeoutException(
    'Stripe Checkout did not become visually ready$detail',
    _screenshotRenderTimeout,
  );
}

Future<bool> _hasVisibleContent(Uint8List screenshot) async {
  if (screenshot.lengthInBytes <= 1024) return false;

  final codec = await ui.instantiateImageCodec(screenshot);
  try {
    final frame = await codec.getNextFrame();
    try {
      if (frame.image.width <= 100 || frame.image.height <= 100) return false;
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (data == null) return false;

      var darkest = 255;
      var lightest = 0;
      var darkPixels = 0;
      final pixelCount = data.lengthInBytes ~/ 4;
      final minimumDarkPixels = max(64, pixelCount ~/ 1000);
      for (var offset = 0; offset < data.lengthInBytes; offset += 4) {
        final red = data.getUint8(offset);
        final green = data.getUint8(offset + 1);
        final blue = data.getUint8(offset + 2);
        final luminance = (299 * red + 587 * green + 114 * blue) ~/ 1000;
        if (luminance < darkest) darkest = luminance;
        if (luminance > lightest) lightest = luminance;
        if (luminance <= _darkPixelLuminance) darkPixels++;
        if (lightest - darkest >= _minimumScreenshotContrast &&
            darkPixels >= minimumDarkPixels) {
          return true;
        }
      }
      return false;
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
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
  Uint8List? screenshot;
  String? lastFailure;
  String? _terminalFailure;

  bool get loaded => uri?.host == _stripeHost;

  bool get finished => loaded || _terminalFailure != null;

  /// Non-null once checkout can no longer succeed.
  String? get failure => _terminalFailure;

  String get failureMessage => lastFailure == null
      ? 'Stripe Checkout did not load a non-empty document'
      : 'Stripe Checkout did not load: $lastFailure';

  Future<void> add(WebViewPageEvent event) async {
    switch (event) {
      case WebViewPageLoaded():
        if (event.uri?.host != _stripeHost) return;
        if (Platform.isMacOS && screenshot == null) {
          try {
            screenshot = await _waitForRenderedScreenshot(
              event.captureScreenshot,
            );
          } catch (error) {
            _terminalFailure = 'Unable to capture WebView screenshot: $error';
            return;
          }
        }
        uri = event.uri;
        documentLength = event.documentLength;
      case WebViewPageLoadFailed():
        lastFailure = '${event.uri?.host ?? 'unknown host'}: ${event.reason}';
        // A main-frame failure anywhere in the redirect chain is terminal
        // for the smoke — don't wait out the full timeout. Cancellation
        // errors fire during normal redirects, so they only count on the
        // Stripe host itself.
        if (event.uri?.host == _stripeHost || !_isCancellation(event.reason)) {
          _terminalFailure = lastFailure;
        }
    }
  }

  static bool _isCancellation(String reason) {
    final lower = reason.toLowerCase();
    return lower.contains('cancel') || lower.contains('abort');
  }
}
