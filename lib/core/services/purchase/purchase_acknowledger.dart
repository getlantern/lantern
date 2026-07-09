import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/failure.dart';

/// Sends a purchase receipt to the backend. Returns the backend response on
/// success, or a [Failure] to be retried.
typedef ReceiptAcknowledger =
    Future<Either<Failure, String>> Function({
      required String purchaseToken,
      required String planId,
      required String couponCode,
    });

/// Resolves the plan id / coupon code to send for a purchase. Re-invoked on
/// each retry so a background attempt reads the latest persisted attribution.
typedef PurchaseResolver = Future<String> Function(PurchaseDetails purchase);

/// Runs after a purchase is confirmed by the backend (or found already active):
/// clear its pending metadata and complete the store transaction.
typedef PurchaseSideEffect = Future<void> Function(PurchaseDetails purchase);

/// The stable key a purchase is deduped/retried under.
typedef RetryKey = String Function(PurchaseDetails purchase);

typedef PurchaseSuccess = void Function(PurchaseDetails purchase);
typedef PurchaseError = void Function(String message);

class _RetryState {
  bool inFlight = false;
  int attempts = 0;
  Timer? timer;
}

/// Owns the "get this receipt confirmed by the backend" state machine:
/// de-duplication of concurrent attempts and background retries with backoff,
/// until the backend confirms or the account is already active.
///
/// All domain operations are injected, so it has no dependency on the service
/// locator or store plugin and is unit-testable in isolation.
class PurchaseAcknowledger {
  PurchaseAcknowledger({
    required ReceiptAcknowledger acknowledgeReceipt,
    required PurchaseResolver resolvePlanId,
    required PurchaseResolver resolveCouponCode,
    required RetryKey retryKeyFor,
    required Future<bool> Function() isAlreadyActive,
    required PurchaseSideEffect onAcknowledged,
    List<Duration> retryDelays = defaultRetryDelays,
    int? maxRetries,
  }) : _acknowledgeReceipt = acknowledgeReceipt,
       _resolvePlanId = resolvePlanId,
       _resolveCouponCode = resolveCouponCode,
       _retryKeyFor = retryKeyFor,
       _isAlreadyActive = isAlreadyActive,
       _onAcknowledged = onAcknowledged,
       _retryDelays = retryDelays,
       // Default to the backoff schedule's length so each defined delay runs
       // exactly once. Previously the final delay repeated forever; capping to
       // the schedule keeps the deliberate 5s→…→5min progression and no more.
       _maxRetries = maxRetries ?? retryDelays.length;

  static const List<Duration> defaultRetryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  final ReceiptAcknowledger _acknowledgeReceipt;
  final PurchaseResolver _resolvePlanId;
  final PurchaseResolver _resolveCouponCode;
  final RetryKey _retryKeyFor;
  final Future<bool> Function() _isAlreadyActive;
  final PurchaseSideEffect _onAcknowledged;
  final List<Duration> _retryDelays;

  /// Max background retries before giving up for this session. The store keeps
  /// the transaction pending (never completed until acknowledged), so it is
  /// re-delivered on the next launch and acknowledgment resumes — capping here
  /// only stops the in-session loop from repeating the final backoff delay
  /// forever (draining battery/network) when the backend is unreachable.
  final int _maxRetries;

  final Map<String, _RetryState> _retries = {};

  /// Acknowledges a freshly delivered [purchase]. On success completes the
  /// store transaction (via `onAcknowledged`) and fires [onSuccess]. On
  /// failure, fires [onError] once and retries in the background with backoff;
  /// background attempts never fire the callbacks again.
  Future<void> acknowledge(
    PurchaseDetails purchase, {
    required String planId,
    required String couponCode,
    required PurchaseSuccess onSuccess,
    required PurchaseError onError,
  }) => _attempt(
    purchase,
    planId: planId,
    couponCode: couponCode,
    onSuccess: onSuccess,
    onError: onError,
    isRetry: false,
  );

  /// Cancels all pending background retries. Not called during normal operation
  /// (retries are meant to outlive a single UI flow); provided for teardown.
  void dispose() {
    for (final state in _retries.values) {
      state.timer?.cancel();
    }
    _retries.clear();
  }

  Future<void> _attempt(
    PurchaseDetails purchase, {
    required String planId,
    required String couponCode,
    required bool isRetry,
    PurchaseSuccess? onSuccess,
    PurchaseError? onError,
  }) async {
    final key = _retryKeyFor(purchase);
    final state = _retries.putIfAbsent(key, () => _RetryState());
    if (state.inFlight) {
      appLogger.info(
        '[PurchaseAck] Acknowledgment already in flight: '
        'productID=${purchase.productID} key=$key',
      );
      return;
    }
    state.inFlight = true;

    try {
      final purchaseToken = purchase.verificationData.serverVerificationData;
      appLogger.info(
        '[PurchaseAck] ${isRetry ? 'retry' : 'start'}: '
        'productID=${purchase.productID} purchaseID=${purchase.purchaseID} '
        'planId=$planId receiptLength=${purchaseToken.length}',
      );

      if (purchaseToken.isEmpty) {
        await _handleFailure(
          purchase,
          'Missing purchase receipt',
          isRetry: isRetry,
          onSuccess: onSuccess,
          onError: onError,
        );
        return;
      }

      // A thrown exception from the backend call (e.g. a network error) is
      // treated exactly like a returned failure, so it is retried rather than
      // propagated to the caller.
      try {
        final result = await _acknowledgeReceipt(
          purchaseToken: purchaseToken,
          planId: planId,
          couponCode: couponCode,
        );

        await result.fold(
          (failure) => _handleFailure(
            purchase,
            failure,
            isRetry: isRetry,
            onSuccess: onSuccess,
            onError: onError,
          ),
          (_) async {
            appLogger.info(
              '[PurchaseAck] Acknowledgment successful: '
              'productID=${purchase.productID} purchaseID=${purchase.purchaseID}',
            );
            _clear(key);
            await _onAcknowledged(purchase);
            if (!isRetry) onSuccess?.call(purchase);
          },
        );
      } catch (e) {
        await _handleFailure(
          purchase,
          e,
          isRetry: isRetry,
          onSuccess: onSuccess,
          onError: onError,
        );
      }
    } finally {
      // May already be gone from the map after a successful `_clear`.
      _retries[key]?.inFlight = false;
    }
  }

  Future<void> _handleFailure(
    PurchaseDetails purchase,
    Object error, {
    required bool isRetry,
    PurchaseSuccess? onSuccess,
    PurchaseError? onError,
  }) async {
    appLogger.error(
      '[PurchaseAck] Acknowledgment failed; leaving store transaction pending '
      'for retry: productID=${purchase.productID} '
      'purchaseID=${purchase.purchaseID}',
      error,
    );

    // The backend may have granted access even though this call failed (e.g. a
    // prior attempt won the race). Trust fresh account state over the error.
    if (await _isAlreadyActive()) {
      appLogger.info(
        '[PurchaseAck] Account already active after failure; finalizing: '
        'productID=${purchase.productID}',
      );
      _clear(_retryKeyFor(purchase));
      await _onAcknowledged(purchase);
      if (!isRetry) onSuccess?.call(purchase);
      return;
    }

    if (!isRetry) {
      onError?.call(
        'Purchase verification failed. We will retry in the background.',
      );
    }
    _scheduleRetry(purchase);
  }

  void _scheduleRetry(PurchaseDetails purchase) {
    final key = _retryKeyFor(purchase);
    final state = _retries.putIfAbsent(key, () => _RetryState());
    if (state.timer != null) {
      appLogger.info(
        '[PurchaseAck] Retry already scheduled: '
        'productID=${purchase.productID} key=$key',
      );
      return;
    }

    if (state.attempts >= _maxRetries) {
      appLogger.warning(
        '[PurchaseAck] Max retries ($_maxRetries) exhausted this session; '
        'giving up until re-delivery on next launch: '
        'productID=${purchase.productID} purchaseID=${purchase.purchaseID}',
      );
      _clear(_retryKeyFor(purchase));
      return;
    }

    final delay = _delayForAttempt(state.attempts);
    appLogger.info(
      '[PurchaseAck] Scheduling retry ${state.attempts + 1} in $delay: '
      'productID=${purchase.productID} purchaseID=${purchase.purchaseID}',
    );

    state.timer = Timer(delay, () {
      unawaited(() async {
        try {
          final planId = await _resolvePlanId(purchase);
          final couponCode = await _resolveCouponCode(purchase);
          state.timer = null;
          state.attempts += 1;
          await _attempt(
            purchase,
            planId: planId,
            couponCode: couponCode,
            isRetry: true,
          );
        } catch (e, st) {
          state.timer = null;
          appLogger.error('[PurchaseAck] Retry attempt threw', e, st);
          await _handleFailure(purchase, e, isRetry: true);
        }
      }());
    });
  }

  Duration _delayForAttempt(int attempt) {
    final index = attempt >= _retryDelays.length
        ? _retryDelays.length - 1
        : attempt;
    return _retryDelays[index];
  }

  void _clear(String key) {
    _retries.remove(key)?.timer?.cancel();
  }
}
