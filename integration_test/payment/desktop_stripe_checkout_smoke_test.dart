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
import 'package:lantern/core/models/plan_data.dart' as plan_models;
import 'package:lantern/core/widgets/app_webview.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/plans/provider/plans_notifier.dart';
import 'package:lantern/lantern_app.dart';
import 'package:lantern/main.dart' as app;

const _stripeHost = 'checkout.stripe.com';
const _e2eHost = 'api.staging.iantem.io';
const _smokeMode = String.fromEnvironment(
  'PAYMENT_SMOKE_MODE',
  defaultValue: 'render',
);
const _screenshotPath = String.fromEnvironment('PAYMENT_SMOKE_SCREENSHOT_PATH');
const _screenshotRenderTimeout = Duration(seconds: 30);
const _screenshotPollInterval = Duration(milliseconds: 250);
const _minimumScreenshotContrast = 64;
const _darkPixelLuminance = 192;

enum _PaymentSmokeMode { render, conversion }

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final mode = switch (_smokeMode) {
    'render' => _PaymentSmokeMode.render,
    'conversion' => _PaymentSmokeMode.conversion,
    _ => throw StateError('Unsupported PAYMENT_SMOKE_MODE: $_smokeMode'),
  };

  testWidgets(
    mode == _PaymentSmokeMode.render
        ? 'staging Stripe Checkout renders in the desktop WebView'
        : 'staging E2E checkout converts the Windows app to Pro',
    (tester) async {
      expect(
        Platform.isWindows || Platform.isMacOS,
        isTrue,
        reason: 'Payment smoke tests run only on desktop',
      );
      if (mode == _PaymentSmokeMode.conversion) {
        expect(
          Platform.isWindows,
          isTrue,
          reason: 'Payment conversion currently runs on Windows CI',
        );
      }

      final runningApp = await _launchApp(tester);
      switch (mode) {
        case _PaymentSmokeMode.render:
          await _runStripeRenderSmoke(tester, runningApp);
        case _PaymentSmokeMode.conversion:
          await _runPaymentConversionSmoke(tester, runningApp);
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

Future<_RunningApp> _launchApp(WidgetTester tester) async {
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
  expect(plans.plans, isNotEmpty, reason: 'Staging returned no plans');
  return _RunningApp(container: container, plans: plans);
}

Future<void> _runStripeRenderSmoke(
  WidgetTester tester,
  _RunningApp runningApp,
) async {
  final stripe = runningApp.plans.providers.desktop.where(
    (provider) => provider.providers.name == 'stripe',
  );
  expect(stripe, isNotEmpty, reason: 'Staging did not return Stripe');
  expect(
    stripe.first.providers.supportSubscription,
    isTrue,
    reason: 'Staging Stripe must support subscriptions',
  );

  _selectBestPlan(runningApp);
  final observer = _StripeCheckoutObserver();
  await _openPaymentMethods(
    email: 'e2e+${_newUuid()}@getlantern.org',
    observer: observer,
  );
  await _startCheckout(tester, provider: 'stripe');

  await _waitFor(
    tester,
    () => observer.finished,
    timeout: const Duration(minutes: 3),
    failure: () => observer.failureMessage,
  );

  if (observer.failure != null) {
    fail('Stripe Checkout failed to load: ${observer.failure}');
  }
  expect(find.byKey(const ValueKey('app-webview')), findsOneWidget);
  expect(observer.uri?.host, _stripeHost);
  expect(observer.documentLength, greaterThan(0));
  expect(observer.screenshot, isNotNull);
  debugPrint(
    'Stripe Checkout rendered from $_stripeHost '
    '(${observer.documentLength} document characters)',
  );
}

Future<void> _runPaymentConversionSmoke(
  WidgetTester tester,
  _RunningApp runningApp,
) async {
  final runID = _newUuid();
  final e2eProvider = plan_models.Android(
    method: 'E2E Checkout',
    providers: plan_models.Provider(
      name: 'e2e',
      icons: const [],
      supportSubscription: false,
    ),
  );
  final plansWithE2E = runningApp.plans.copyWith(
    providers: plan_models.Providers(
      android: runningApp.plans.providers.android,
      desktop: [e2eProvider, ...runningApp.plans.providers.desktop],
    ),
  );
  runningApp.container.read(plansProvider.notifier).updatePlans(plansWithE2E);
  _selectBestPlan(
    _RunningApp(container: runningApp.container, plans: plansWithE2E),
  );

  final observer = _PaymentConversionObserver();
  await _openPaymentMethods(
    email: 'e2e+$runID@getlantern.org',
    observer: observer,
  );
  await _startCheckout(tester, provider: 'e2e');

  await _waitFor(
    tester,
    () => observer.completeClicked || observer.failure != null,
    timeout: const Duration(minutes: 2),
    failure: () => observer.failureMessage,
  );
  if (observer.failure != null) {
    fail('E2E checkout failed: ${observer.failure}');
  }

  await _waitFor(
    tester,
    () =>
        runningApp.container.read(homeProvider).value?.legacyUserData.isPro ==
        true,
    timeout: const Duration(minutes: 2),
    failure: () => 'The staging account did not become Pro',
  );
  await _waitFor(
    tester,
    () => find.text('welcome_to_lantern_pro'.i18n).evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    failure: () => 'The Lantern Pro success dialog was not shown',
  );

  expect(observer.uri?.host, _e2eHost);
  expect(observer.documentLength, greaterThan(0));
  expect(observer.screenshot, isNotNull);
  expect(
    runningApp.container.read(homeProvider).value?.legacyUserData.isPro,
    isTrue,
  );
  debugPrint('Staging E2E checkout converted run $runID to Pro');
}

void _selectBestPlan(_RunningApp runningApp) {
  final selectedPlan = runningApp.plans.plans.firstWhere(
    (plan) => plan.bestValue,
    orElse: () => runningApp.plans.plans.first,
  );
  runningApp.container
      .read(plansProvider.notifier)
      .setSelectedPlan(selectedPlan);
}

Future<void> _openPaymentMethods({
  required String email,
  required AppWebViewObserver observer,
}) {
  return appRouter.replaceAll([
    ChoosePaymentMethod(
      email: email,
      authFlow: AuthFlow.renewSubscription,
      checkoutObserver: observer,
    ),
  ]);
}

Future<void> _startCheckout(
  WidgetTester tester, {
  required String provider,
}) async {
  final providerTile = find.byKey(Key('payment.provider.$provider'));
  await _waitFor(
    tester,
    () => providerTile.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    failure: () => '$provider was not shown on the payment-method screen',
  );

  final checkoutButton = find.byKey(Key('payment.checkout.$provider'));
  if (checkoutButton.evaluate().isEmpty) {
    await tester.tap(providerTile);
    await tester.pump(const Duration(milliseconds: 300));
  }
  await _waitFor(
    tester,
    () => checkoutButton.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 10),
    failure: () => '$provider checkout button was not available',
  );

  await tester.ensureVisible(checkoutButton);
  await tester.tap(checkoutButton);
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
    'Checkout did not become visually ready$detail',
    _screenshotRenderTimeout,
  );
}

Future<void> _saveScreenshot(Uint8List screenshot) async {
  if (_screenshotPath.isEmpty) return;
  final file = File(_screenshotPath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(screenshot, flush: true);
  debugPrint('Checkout screenshot saved to ${file.path}');
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

bool _isJavaScriptTrue(Object? value) =>
    value == true || value == 1 || value?.toString().toLowerCase() == 'true';

class _RunningApp {
  final ProviderContainer container;
  final plan_models.PlansData plans;

  const _RunningApp({required this.container, required this.plans});
}

class _StripeCheckoutObserver implements AppWebViewObserver {
  Uri? uri;
  int documentLength = 0;
  Uint8List? screenshot;
  String? lastFailure;
  String? failure;

  bool get finished => uri?.host == _stripeHost || failure != null;

  String get failureMessage => lastFailure == null
      ? 'Stripe Checkout did not load a non-empty document'
      : 'Stripe Checkout did not load: $lastFailure';

  @override
  Future<void> onPageLoaded(
    Uri uri, {
    required int documentLength,
    required Future<Uint8List?> Function() captureScreenshot,
    required Future<Object?> Function(String source) evaluateJavaScript,
  }) async {
    if (uri.host != _stripeHost) return;
    try {
      screenshot = await _waitForRenderedScreenshot(captureScreenshot);
      await _saveScreenshot(screenshot!);
    } catch (error) {
      failure = 'Unable to capture WebView screenshot: $error';
    }
    this.uri = uri;
    this.documentLength = documentLength;
  }

  @override
  void onPageLoadFailed(Uri? uri, String reason) {
    lastFailure = '${uri?.host ?? 'unknown host'}: $reason';
    if (uri?.host == _stripeHost) {
      failure = reason;
    }
  }
}

class _PaymentConversionObserver implements AppWebViewObserver {
  static const _clickCompleteScript = r'''
    (() => {
      const candidates = Array.from(
        document.querySelectorAll('button, input[type="button"], input[type="submit"], a')
      );
      const complete = candidates.find((element) => {
        const label = (
          element.innerText || element.value || element.textContent || ''
        ).trim().toLowerCase();
        return label === 'complete';
      });
      if (!complete) return false;
      complete.click();
      return true;
    })()
  ''';

  Uri? uri;
  int documentLength = 0;
  Uint8List? screenshot;
  bool completeClicked = false;
  bool _completionStarted = false;
  String? failure;

  String get failureMessage =>
      failure ?? 'The staging E2E completion control was not available';

  @override
  Future<void> onPageLoaded(
    Uri uri, {
    required int documentLength,
    required Future<Uint8List?> Function() captureScreenshot,
    required Future<Object?> Function(String source) evaluateJavaScript,
  }) async {
    if (uri.host != _e2eHost || _completionStarted) return;
    _completionStarted = true;
    this.uri = uri;
    this.documentLength = documentLength;

    try {
      screenshot = await _waitForRenderedScreenshot(captureScreenshot);
      await _saveScreenshot(screenshot!);

      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        final result = await evaluateJavaScript(
          _clickCompleteScript,
        ).timeout(const Duration(seconds: 5));
        if (_isJavaScriptTrue(result)) {
          completeClicked = true;
          return;
        }
        await Future<void>.delayed(_screenshotPollInterval);
      }
      failure = 'The staging E2E completion control was not found';
    } catch (error) {
      failure = 'Unable to complete the staging checkout: $error';
    }
  }

  @override
  void onPageLoadFailed(Uri? uri, String reason) {
    if (uri == null || uri.host == _e2eHost) {
      failure = '${uri?.host ?? 'unknown host'}: $reason';
    }
  }
}
