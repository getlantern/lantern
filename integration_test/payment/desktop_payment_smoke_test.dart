import 'dart:async';
import 'dart:io';
import 'dart:math' show max;
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
import 'package:lantern/main.dart' as app;

import '../utils/app_robot.dart';
import '../utils/payment_robot.dart';

const _stripeHost = 'checkout.stripe.com';
const _e2eHost = 'api.staging.iantem.io';
const _artifactDirectory = String.fromEnvironment('PAYMENT_SMOKE_ARTIFACT_DIR');
const _screenshotRenderTimeout = Duration(seconds: 30);
const _screenshotPollInterval = Duration(milliseconds: 250);
const _minimumScreenshotContrast = 64;
const _darkPixelLuminance = 192;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'staging checkout renders and converts to Pro',
    (tester) async {
      expect(
        Platform.isWindows || Platform.isMacOS,
        isTrue,
        reason: 'Payment smoke tests run only on desktop',
      );

      final runningApp = await _launchApp(tester);
      await _runStripeRenderSmoke(tester, runningApp);
      if (Platform.isWindows) {
        await _runPaymentConversionSmoke(tester, runningApp);
      }
    },
    timeout: const Timeout(Duration(minutes: 14)),
  );
}

Future<_RunningApp> _launchApp(WidgetTester tester) async {
  await app.main();
  final robot = AppRobot(tester);
  await robot.waitForHomeReady();
  final payment = PaymentRobot(tester, robot);
  final plans = await payment.loadPlans();
  expect(plans.plans, isNotEmpty, reason: 'Staging returned no plans');
  return _RunningApp(payment: payment, plans: plans);
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

  runningApp.payment.selectBestValuePlan(runningApp.plans);
  final checkout = _StripeCheckoutTracker();
  await runningApp.payment.openPaymentMethods(
    email: e2eEmail(),
    authFlow: AuthFlow.renewSubscription,
    checkoutObserver: checkout,
  );
  await runningApp.payment.startCheckout(provider: 'stripe');

  await _waitFor(
    tester,
    () => checkout.finished,
    timeout: const Duration(minutes: 3),
    failure: () => checkout.failureMessage,
  );

  if (checkout.failure != null) {
    fail('Stripe Checkout failed to load: ${checkout.failure}');
  }
  expect(find.byKey(const ValueKey('app-webview')), findsOneWidget);
  expect(checkout.uri?.host, _stripeHost);
  expect(checkout.documentLength, greaterThan(0));
  expect(checkout.screenshot, isNotNull);
  e2eLog(
    'Stripe Checkout rendered from $_stripeHost '
    '(${checkout.documentLength} document characters)',
  );
}

/// Providers converted in order on one e2e account. The Shepherd ones run
/// through staging's fake gateway, so each one exercises the signed callback.
/// Where staging has no fake gateway, they're skipped.
const _conversionProviders = <(String name, String method)>[
  ('e2e', 'E2E Checkout'),
  ('shepherd-wechat', 'wechatpay'),
  ('shepherd', 'alipay'),
];

Future<void> _runPaymentConversionSmoke(
  WidgetTester tester,
  _RunningApp runningApp,
) async {
  final runID = newE2ERunID();

  // Staging may not offer every provider (the WeChat flag is off there), so
  // missing ones are added client-side, and re-added if plans are refetched.
  plan_models.PlansData withConversionProviders(plan_models.PlansData plans) {
    final missing = _conversionProviders
        .where(
          (p) => !plans.providers.desktop.any((d) => d.providers.name == p.$1),
        )
        .map(
          (p) => plan_models.Android(
            method: p.$2,
            providers: plan_models.Provider(
              name: p.$1,
              icons: const [],
              supportSubscription: false,
            ),
          ),
        )
        .toList();
    if (missing.isEmpty) return plans;
    return plans.copyWith(
      providers: plan_models.Providers(
        android: plans.providers.android,
        desktop: [...missing, ...plans.providers.desktop],
      ),
    );
  }

  void ensureConversionProviders() {
    final currentPlans = runningApp.container.read(plansProvider).value;
    if (currentPlans == null) return;
    final updated = withConversionProviders(currentPlans);
    if (identical(updated, currentPlans)) return;
    runningApp.container.read(plansProvider.notifier).updatePlans(updated);
  }

  final providerSubscription = runningApp.container.listen(plansProvider, (
    _,
    next,
  ) {
    final plans = next.value;
    if (plans == null || identical(withConversionProviders(plans), plans)) {
      return;
    }
    scheduleMicrotask(ensureConversionProviders);
  });
  addTearDown(providerSubscription.close);

  for (final (provider, _) in _conversionProviders) {
    await _convertWith(tester, runningApp, runID, provider, () {
      final currentPlans = runningApp.container.read(plansProvider).value;
      final plans = withConversionProviders(currentPlans ?? runningApp.plans);
      runningApp.container.read(plansProvider.notifier).updatePlans(plans);
      return plans;
    });
  }
}

Future<void> _convertWith(
  WidgetTester tester,
  _RunningApp runningApp,
  String runID,
  String provider,
  plan_models.PlansData Function() preparePlans,
) async {
  int expiration() =>
      runningApp.container
          .read(homeProvider)
          .value
          ?.legacyUserData
          .expiration ??
      0;
  final expirationBefore = expiration();
  runningApp.payment.selectBestValuePlan(preparePlans());

  final checkout = _PaymentConversionTracker(provider);
  await runningApp.payment.openPaymentMethods(
    email: e2eEmail(runID),
    authFlow: AuthFlow.renewSubscription,
    checkoutObserver: checkout,
  );
  await runningApp.payment.startCheckout(provider: provider);

  final viaShepherd = provider.startsWith('shepherd');
  await _waitFor(
    tester,
    () =>
        checkout.completionRequested ||
        checkout.failure != null ||
        (viaShepherd && checkout.otherHost != null),
    timeout: const Duration(minutes: 2),
    failure: () => checkout.failureMessage,
  );
  if (checkout.failure != null) {
    fail('$provider checkout failed: ${checkout.failure}');
  }
  if (!checkout.completionRequested) {
    // Without the fake gateway, staging sends Shepherd checkouts to the real
    // one, which a test can't pay.
    e2eLog(
      'Skipping $provider: staging opened ${checkout.otherHost}, not the '
      'fake Shepherd gateway',
    );
    return;
  }

  // Each conversion has to extend Pro: after the first one the account is
  // already Pro, so isPro alone proves nothing.
  await _waitFor(
    tester,
    () =>
        (runningApp.container.read(homeProvider).value?.legacyUserData.isPro ==
                true &&
            expiration() > expirationBefore) ||
        checkout.failure != null,
    timeout: const Duration(minutes: 2),
    failure: () => checkout.proConversionFailureMessage,
  );
  if (checkout.failure != null) {
    fail('$provider checkout failed after completion: ${checkout.failure}');
  }
  final welcome = find.text('welcome_to_lantern_pro'.i18n);
  await _waitFor(
    tester,
    () => welcome.evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
    failure: () => 'The Lantern Pro success dialog was not shown for $provider',
  );

  expect(checkout.uri?.host, _e2eHost);
  expect(checkout.documentLength, greaterThan(0));
  expect(checkout.screenshot, isNotNull);
  e2eLog(
    'Staging $provider checkout extended run $runID from '
    '$expirationBefore to ${expiration()}',
  );

  await tester.tap(find.text('continue'.i18n).last);
  await _waitFor(
    tester,
    () => welcome.evaluate().isEmpty,
    timeout: const Duration(seconds: 10),
    failure: () => 'The Lantern Pro success dialog did not close',
  );
  // Continue runs popUntilRoot after a delay. Let it fire before the next
  // checkout opens, or it can pop the new webview.
  await tester.pump(AppDialog.actionDelay + const Duration(milliseconds: 200));
  await tester.pump();
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

Future<void> _saveScreenshot(Uint8List screenshot, String name) async {
  if (_artifactDirectory.isEmpty) return;
  final file = File('$_artifactDirectory${Platform.pathSeparator}$name');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(screenshot, flush: true);
  e2eLog('Checkout screenshot saved to ${file.path}');
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

bool _isJavaScriptTrue(Object? value) =>
    value == true || value == 1 || value?.toString().toLowerCase() == 'true';

class _RunningApp {
  final PaymentRobot payment;
  final plan_models.PlansData plans;

  const _RunningApp({required this.payment, required this.plans});

  ProviderContainer get container => payment.container;
}

/// Folds scoped WebView callbacks into a stateful Stripe checkout verdict.
class _StripeCheckoutTracker implements AppWebViewObserver {
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
      await _saveScreenshot(screenshot!, 'stripe-checkout.png');
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

/// Tracks the staging checkout state and completes it through the WebView.
class _PaymentConversionTracker implements AppWebViewObserver {
  _PaymentConversionTracker(this.provider);

  final String provider;

  static const _findCompleteScript = r'''
    (() => {
      const candidates = Array.from(
        document.querySelectorAll('button, input[type="button"], input[type="submit"], a')
      );
      return candidates.some((element) => {
        const label = (
          element.innerText || element.value || element.textContent || ''
        ).trim().toLowerCase();
        return label === 'complete';
      });
    })()
  ''';

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
  bool completionRequested = false;
  bool _completionInProgress = false;
  String? _handoffDiagnostic;
  String? _otherHost;
  String? failure;

  /// The first checkout page that wasn't on the staging host.
  String? get otherHost => _otherHost;

  String get failureMessage {
    if (failure != null) return failure!;
    final other = _otherHost;
    return other == null
        ? 'The staging E2E completion control was not available'
        : '$provider checkout opened $other instead of the staging test '
              'checkout; is the fake Shepherd gateway deployed to staging?';
  }

  String get proConversionFailureMessage {
    final diagnostic = _handoffDiagnostic;
    return diagnostic == null
        ? 'The staging account did not become Pro'
        : 'The staging account did not become Pro after $diagnostic';
  }

  @override
  Future<void> onPageLoaded(
    Uri uri, {
    required int documentLength,
    required Future<Uint8List?> Function() captureScreenshot,
    required Future<Object?> Function(String source) evaluateJavaScript,
  }) async {
    if (uri.host != _e2eHost) {
      _otherHost ??= uri.host;
      return;
    }
    if (completionRequested || _completionInProgress) return;
    _completionInProgress = true;
    this.uri = uri;
    this.documentLength = documentLength;

    try {
      screenshot = await _waitForRenderedScreenshot(captureScreenshot);
      await _saveScreenshot(screenshot!, 'payment-conversion-$provider.png');

      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        final controlReady = await evaluateJavaScript(
          _findCompleteScript,
        ).timeout(const Duration(seconds: 5));
        if (_isJavaScriptTrue(controlReady)) {
          // WebView2 reports CONNECTION_ABORTED when Lantern intercepts the
          // successful callback and closes the checkout. Mark the handoff
          // before clicking so that expected cancellation cannot race the
          // JavaScript result back to Dart.
          completionRequested = true;
          try {
            final clicked = await evaluateJavaScript(
              _clickCompleteScript,
            ).timeout(const Duration(seconds: 5));
            if (!_isJavaScriptTrue(clicked)) {
              failure = 'The staging E2E completion control disappeared';
            }
          } catch (error) {
            _handoffDiagnostic = 'the WebView handoff was interrupted: $error';
            e2eLog(_handoffDiagnostic!);
          }
          return;
        }
        await Future<void>.delayed(_screenshotPollInterval);
      }
    } catch (error) {
      failure = 'Unable to complete the staging checkout: $error';
    } finally {
      _completionInProgress = false;
    }
  }

  @override
  void onPageLoadFailed(Uri? uri, String reason) {
    if (completionRequested &&
        reason.toUpperCase().contains('CONNECTION_ABORTED')) {
      e2eLog('Ignoring expected WebView cancellation after completion handoff');
      return;
    }
    if (uri == null || uri.host == _e2eHost) {
      failure = '${uri?.host ?? 'unknown host'}: $reason';
    }
  }
}
