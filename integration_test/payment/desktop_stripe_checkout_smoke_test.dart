import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/app_webview.dart';
import 'package:lantern/main.dart' as app;

import '../utils/app_robot.dart';
import '../utils/payment_robot.dart';

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
      final payment = PaymentRobot(tester, robot);
      await robot.waitForHomeReady();

      final plans = await payment.loadPlans();
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
      payment.selectBestValuePlan(plans);

      final checkout = _StripeCheckoutTracker();
      final pageEventSubscription = payment.container.listen(
        webViewPageEventProvider,
        (_, event) {
          if (event != null) unawaited(checkout.add(event));
        },
      );
      addTearDown(pageEventSubscription.close);

      await payment.openPaymentMethods(
        email: e2eEmail(),
        authFlow: AuthFlow.renewSubscription,
      );
      await payment.startStripeCheckout();

      await _waitForCheckout(tester, checkout);

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

/// Waits until the tracker sees Stripe load or fail — a state wait, not a
/// widget wait, so the robot's finder-based helpers don't apply.
Future<void> _waitForCheckout(
  WidgetTester tester,
  _StripeCheckoutTracker checkout,
) async {
  final deadline = DateTime.now().add(const Duration(minutes: 3));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (checkout.finished) return;
  }
  fail(checkout.failureMessage);
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
