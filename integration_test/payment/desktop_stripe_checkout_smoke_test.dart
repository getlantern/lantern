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
import 'package:lantern/lantern_app.dart';
import 'package:lantern/main.dart' as app;

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
      if (Platform.isMacOS) {
        final screenshot = observer.screenshot;
        if (screenshot == null) {
          fail('The Stripe WebView did not return a screenshot');
        }
        if (_screenshotPath.isNotEmpty) {
          final file = File(_screenshotPath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(screenshot, flush: true);
          debugPrint('Stripe Checkout screenshot saved to ${file.path}');
        }
      }
      debugPrint(
        'Stripe Checkout rendered from $_stripeHost '
        '(${observer.documentLength} document characters)',
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
  Uint8List? screenshot;
  String? lastFailure;
  String? checkoutFailure;

  bool get finished => uri?.host == _stripeHost || checkoutFailure != null;

  String get failureMessage => lastFailure == null
      ? 'Stripe Checkout did not load a non-empty document'
      : 'Stripe Checkout did not load: $lastFailure';

  @override
  Future<void> onPageLoaded(
    Uri uri, {
    required int documentLength,
    required Future<Uint8List?> Function() captureScreenshot,
  }) async {
    if (uri.host != _stripeHost) return;
    if (Platform.isMacOS) {
      try {
        screenshot = await _waitForRenderedScreenshot(captureScreenshot);
      } catch (error) {
        checkoutFailure = 'Unable to capture WebView screenshot: $error';
      }
    }
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
