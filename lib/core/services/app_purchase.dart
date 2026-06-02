import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

import 'injection_container.dart' show sl;
import 'local_storage_service.dart';

typedef PaymentSuccessCallback = void Function(PurchaseDetails purchase);
typedef PaymentErrorCallback = void Function(String error);

class AppPurchase {
  static const _pendingPurchasePlansKey = 'pending_purchase_plans_json';
  static const _productPlanKeyPrefix = 'product:';
  static const _transactionPlanKeyPrefix = 'transaction:';
  static const _ackRetryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final List<ProductDetails> _subscriptionSku = [];
  final List<String> _subscriptionIds = <String>['1m_sub', '1y_sub'];
  final Set<String> _acknowledgeInFlight = {};
  final Map<String, int> _ackRetryAttempts = {};
  final Map<String, Timer> _ackRetryTimers = {};

  PaymentSuccessCallback? _onSuccess;
  PaymentErrorCallback? _onError;

  // Tracks whether we have real product details loaded
  bool _productsLoaded = false;
  Completer<void>? _productsLoadedCompleter;

  // Track what plan the user selected
  String? _pendingPlanId;

  // True while a restore flow is in progress; restored receipts should be
  // acknowledged so the backend can reassociate the user, even when the
  // device has no active subscription cached locally.
  bool _isRestoreFlow = false;

  // Set true when a restored receipt is delivered through the stream during
  // a restore flow. Used on iOS to detect "no purchases" (StoreKit doesn't
  // emit an empty stream event the way Play Billing does).
  bool _restoreReceivedAny = false;

  void init() {
    if (!_canInitializeStorePurchases()) {
      return;
    }

    appLogger.info(
      '[AppPurchase] Subscribing to purchaseStream '
      '(platform=${Platform.operatingSystem}, country=${CountryCode.current})',
    );
    _subscription = _inAppPurchase.purchaseStream.listen(
      _onPurchaseUpdates,
      onDone: _updateStreamOnDone,
      onError: _updateStreamOnError,
    );
    unawaited(
      fetchSubscriptions().catchError((Object e, StackTrace st) {
        appLogger.error('[AppPurchase] init: fetchSubscriptions failed', e, st);
      }),
    );
  }

  bool _canInitializeStorePurchases() {
    if (PlatformUtils.isDesktop) {
      appLogger.debug('[AppPurchase] Skipping init: desktop platform');
      return false;
    }
    if (_subscription != null) {
      appLogger.debug('[AppPurchase] Skipping init: already subscribed');
      return false;
    }
    if (!Platform.isAndroid) {
      return true;
    }
    // Subscribing to purchaseStream initializes BillingClient, which OOMs
    // the Dalvik heap via an internal reconnect loop when Play Billing
    // isn't reachable. See getlantern/engineering#3485.
    final allowed = canUsePlayBilling();
    if (!allowed) {
      appLogger.info(
        '[AppPurchase] Skipping Play Billing init: canUsePlayBilling=false '
        '(country=${CountryCode.current}, censored=${CountryCode.isCensoredRegion})',
      );
    }
    return allowed;
  }

  Future<bool> _initPlayBillingIfAllowed() async {
    appLogger.info(
      '[AppPurchase] _initPlayBillingIfAllowed: '
      'country=${CountryCode.current}, isKnown=${CountryCode.isKnown}, '
      'subscribed=${_subscription != null}',
    );
    init();
    if (_subscription != null) {
      appLogger.info('[AppPurchase] _initPlayBillingIfAllowed: ready');
      return true;
    }
    if (Platform.isAndroid && !CountryCode.isKnown) {
      appLogger.info(
        '[AppPurchase] _initPlayBillingIfAllowed: country unknown, '
        'waiting for country-code event…',
      );
      final known = await CountryCode.waitUntilKnown();
      appLogger.info(
        '[AppPurchase] _initPlayBillingIfAllowed: waitUntilKnown returned '
        '$known (country=${CountryCode.current}); retrying init',
      );
      init();
    }
    final ready = _subscription != null;
    appLogger.info('[AppPurchase] _initPlayBillingIfAllowed: ready=$ready');
    return ready;
  }

  Future<void> fetchSubscriptions({int maxAttempts = 3}) async {
    // If a fetch is already running, piggy-back on its result.
    if (_productsLoadedCompleter != null) {
      return _productsLoadedCompleter!.future;
    }
    _productsLoaded = false;
    _productsLoadedCompleter = Completer<void>();

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        appLogger.info(
          '[AppPurchase] Fetching subscriptions, attempt: ${attempt + 1}/$maxAttempts',
        );

        final response = await _inAppPurchase.queryProductDetails(
          _subscriptionIds.toSet(),
        );

        if (response.error != null) {
          appLogger.error(
            '[AppPurchase] Error fetching subscriptions: ${response.error}',
          );
        } else if (response.productDetails.isEmpty) {
          appLogger.error(
            '[AppPurchase] Fetched 0 subscriptions. notFoundIDs=${response.notFoundIDs}',
          );
        } else {
          _subscriptionSku
            ..clear()
            ..addAll(response.productDetails);

          _productsLoaded = true;
          if (!(_productsLoadedCompleter?.isCompleted ?? true)) {
            _productsLoadedCompleter?.complete();
          }
          appLogger.info(
            '[AppPurchase] Fetched subscriptions: ${_subscriptionSku.length} items',
          );
          return;
        }
      } catch (e, st) {
        appLogger.error('[AppPurchase] Error fetching subscriptions', e, st);
      }

      if (attempt < maxAttempts - 1) {
        final delayMs = 500 * (1 << attempt);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    // All retries are exhausted. On Android this is a useful signal that
    // Play Billing is blocked or unavailable, so offer the non-store flow.
    if (Platform.isAndroid && !CountryCode.isCensoredRegion) {
      appLogger.warning(
        '[AppPurchase] Play Billing unreachable after $maxAttempts attempts; '
        'marking region as censored to fall back to Stripe.',
      );
      CountryCode.markCensored();
    }

    final error = StateError(
      'Unable to load App Store products after $maxAttempts attempts',
    );
    //  Safely complete the completer with an error, if it is still pending.
    if (_productsLoadedCompleter != null &&
        !_productsLoadedCompleter!.isCompleted) {
      _productsLoadedCompleter!.completeError(error);
    }
    throw error;
  }

  /// Ensures products are available before starting a purchase.
  Future<void> _waitForProducts() async {
    if (_productsLoaded) return;

    // If a fetch is already in progress, piggy-back on it.
    if (_productsLoadedCompleter != null &&
        !_productsLoadedCompleter!.isCompleted) {
      await _productsLoadedCompleter!.future;
      return;
    }

    // No active fetch — reset so fetchSubscriptions creates a fresh completer.
    _productsLoadedCompleter = null;
    await fetchSubscriptions();
  }

  Future<bool> isAvailable() async {
    return await InAppPurchase.instance.isAvailable();
  }

  /// Starts the subscription flow and only triggers the callbacks related to this purchase.
  Future<void> startSubscription({
    required String plan,
    required PaymentSuccessCallback onSuccess,
    required void Function(String error) onError,
  }) async {
    _onSuccess = onSuccess;
    _onError = onError;
    // Store the exact plan id user chose (ex: "1y-usd-10")
    _pendingPlanId = plan;

    if (!await _initPlayBillingIfAllowed()) {
      _onError?.call(
        "Unable to load App Store products. Check your network and try again.",
      );
      return;
    }

    try {
      await _waitForProducts();
    } catch (_) {
      _onError?.call(
        "Unable to load App Store products. Check your network and try again.",
      );
      return;
    }

    final product = _normalizePlan(plan);
    if (product == null) {
      _onError?.call("Invalid plan: $plan");
      return;
    }

    final PurchaseParam purchaseParam;
    if (Platform.isAndroid && product is GooglePlayProductDetails) {
      purchaseParam = GooglePlayPurchaseParam(
        productDetails: product,
        offerToken: product.offerToken,
      );
    } else {
      purchaseParam = PurchaseParam(productDetails: product);
    }

    try {
      appLogger.info(
        '[AppPurchase] Initiating purchase for product: ${product.id} with pendingPlanId: $_pendingPlanId',
      );
      await _rememberPendingPlanForProduct(product.id, plan);
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!started) {
        await _forgetPendingPlanForProduct(product.id);
        _onError?.call("Failed to initiate purchase flow.");
      }
    } catch (e) {
      await _forgetPendingPlanForProduct(product.id);
      _onError?.call("Error starting subscription: $e");
    }
  }

  /// Restores prior purchases from the platform store.
  ///
  /// On iOS this triggers StoreKit's restore flow; on Android it surfaces
  /// active Google Play Billing purchases through the same purchase stream.
  /// Restored receipts are acknowledged with the backend so the current user
  /// (or the user matching the receipt, if unauthenticated) is associated
  /// with the subscription.
  Future<void> restorePurchases({
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) async {
    _onSuccess = onSuccess;
    _onError = onError;
    _isRestoreFlow = true;
    _restoreReceivedAny = false;
    _pendingPlanId = null;

    if (!await _initPlayBillingIfAllowed()) {
      _isRestoreFlow = false;
      final onError = _onError;
      clearCallbacks();
      onError?.call(
        "Unable to load App Store products. Check your network and try again.",
      );
      return;
    }

    try {
      appLogger.info('[AppPurchase] Initiating restore purchases');
      await _inAppPurchase.restorePurchases();
      if (Platform.isIOS) {
        // StoreKit doesn't emit anything via the stream when there are no
        // purchases to restore, so the only signal "nothing to restore" is
        // the absence of a stream event within a reasonable window.
        Future.delayed(const Duration(seconds: 10), () {
          if (_isRestoreFlow && !_restoreReceivedAny) {
            appLogger.info('[AppPurchase] iOS restore: no purchases delivered');
            _isRestoreFlow = false;
            final onError = _onError;
            clearCallbacks();
            onError?.call('No previous purchases found to restore.');
          }
        });
      }
    } catch (e, st) {
      appLogger.error('[AppPurchase] Error restoring purchases', e, st);
      _isRestoreFlow = false;
      final onError = _onError;
      clearCallbacks();
      onError?.call('Error restoring purchases: $e');
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    appLogger.info(
      '[AppPurchase] Received purchase updates: ${purchases.length}',
    );
    if (_isRestoreFlow && purchases.isEmpty) {
      appLogger.info(
        '[AppPurchase] Restore flow: purchase stream emitted empty list',
      );
      _isRestoreFlow = false;
      final onError = _onError;
      clearCallbacks();
      onError?.call('No previous purchases found to restore.');
      return;
    }

    /// During restore, if more than one restored receipt comes back, batch
    /// them: pick one to surface and finalize the rest. Otherwise _finalize
    /// would clear _isRestoreFlow after the first item and the second
    /// iteration would fall into the regular acknowledge path.
    if (_isRestoreFlow && purchases.length > 1) {
      final restored = purchases
          .where(
            (p) =>
                p.status == PurchaseStatus.purchased ||
                p.status == PurchaseStatus.restored,
          )
          .toList();
      if (restored.length > 1) {
        await _handleRestoreBatch(restored);
        return;
      }
    }

    for (final purchase in purchases) {
      await _handlePurchase(purchase);
    }
  }

  /// Picks the latest restored receipt, finalizes every restored receipt
  /// with the store, and fires `_onSuccess` once.
  Future<void> _handleRestoreBatch(List<PurchaseDetails> restored) async {
    ///Pick the latest purchase
    restored.sort((a, b) {
      final aDate = int.tryParse(a.transactionDate ?? '') ?? 0;
      final bDate = int.tryParse(b.transactionDate ?? '') ?? 0;
      return bDate.compareTo(aDate);
    });

    final chosen = restored.first;
    appLogger.info(
      '[AppPurchase] Restore batch: ${restored.length} purchases, choosing ${chosen.productID}',
    );

    _restoreReceivedAny = true;

    // Complete each receipt inline (don't call _finalize — its `finally`
    // clears _isRestoreFlow, which would mis-route any re-entrant stream
    // emissions through the regular acknowledge path mid-batch and fire
    // a stray error before our success callback.
    for (final purchase in restored) {
      try {
        if (purchase.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchase);
        }
      } catch (e) {
        appLogger.error('[AppPurchase] Error completing restored purchase: $e');
      }
    }

    final onSuccess = _onSuccess;
    _isRestoreFlow = false;
    _pendingPlanId = null;
    clearCallbacks();
    onSuccess?.call(chosen);
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    appLogger.info(
      '[AppPurchase] Handling purchase: ${purchaseDetails.productID} with status: ${purchaseDetails.status}',
    );
    try {
      final status = purchaseDetails.status;
      if (status == PurchaseStatus.error) {
        /// Error occurred during purchase
        appLogger.error('Purchase error: ${purchaseDetails.error}');
        final errorMessage = purchaseDetails.error?.message ?? "Unknown error";
        await _forgetPendingPlan(purchaseDetails);
        _pendingPlanId = null;

        /// Invoke error callback
        _onError?.call(errorMessage);
        return;
      }
      if (status == PurchaseStatus.canceled) {
        // `canceled` is not necessarily a real user cancel — the
        // in_app_purchase plugin also maps several silent Google Play
        // rejections (offer ineligibility, missing payment method, region
        // mismatch, billing-service hiccups) to the same status. Without
        // capturing the underlying error we can't distinguish those from a
        // user who actually X'd the dialog, which is the difference between
        // "expected" and "a bug to fix." For Android, `error.details`
        // typically contains a Map with the raw BillingClient
        // `response_code` and `debug_message`.
        appLogger.info(
          '[AppPurchase] Purchase canceled: productID=${purchaseDetails.productID}'
          ' errorCode=${purchaseDetails.error?.code}'
          ' message=${purchaseDetails.error?.message}'
          ' details=${purchaseDetails.error?.details}',
        );
        await _forgetPendingPlan(purchaseDetails);
        _pendingPlanId = null;
        _onError?.call("Purchase canceled");
        return;
      }
      if (status == PurchaseStatus.pending) {
        /// Purchase is pending (e.g. deferred payment method on Android).
        /// Dismiss loading and inform the user — the purchase will complete
        /// asynchronously when the payment is confirmed.
        appLogger.info(
          '[AppPurchase] Purchase is pending: ${purchaseDetails.productID}',
        );
        _onError?.call(
          "Purchase is pending. You will be notified when it completes.",
        );
        return;
      }
      if (status == PurchaseStatus.purchased ||
          status == PurchaseStatus.restored) {
        /// During an explicit restore flow, skip the backend acknowledge call
        if (_isRestoreFlow) {
          appLogger.info(
            '[AppPurchase] Found restore purchase calling success',
          );
          _restoreReceivedAny = true;
          await _finalize(purchaseDetails);
          final onSuccess = _onSuccess;
          clearCallbacks();
          onSuccess?.call(purchaseDetails);
          return;
        }

        /// Apple sends purchase updates for previously purchased items when the app starts.
        /// This check prevents processing the same subscription multiple times.
        if (await _checkIfAlreadyPurchased()) {
          appLogger.info(
            '[AppPurchase] User has already purchased the subscription. Finalizing purchase without processing.',
          );
          await _forgetPendingPlan(purchaseDetails);
          await _finalize(purchaseDetails);
          _onError?.call('You have already purchased this subscription.');
          return;
        }

        try {
          appLogger.info(
            '[AppPurchase] Purchase successful: ${purchaseDetails.productID}',
          );
          final planId = await _resolvePlanId(purchaseDetails);
          await _rememberPendingPlanForPurchase(purchaseDetails, planId);
          await _acknowledgePurchase(purchaseDetails, planId: planId);
        } catch (e, st) {
          await _handleAcknowledgeFailure(purchaseDetails, e, stackTrace: st);
        }
        return;
      }
    } catch (e) {
      appLogger.error('[AppPurchase] Error handling purchase: $e', e);
      _onError?.call(e.toString());
    }
  }

  // Separate helper to ensure the Store is cleared
  Future<void> _finalize(PurchaseDetails purchaseDetails) async {
    try {
      if (purchaseDetails.pendingCompletePurchase) {
        appLogger.info(
          '[AppPurchase] Completing store transaction: '
          'productID=${purchaseDetails.productID} purchaseID=${purchaseDetails.purchaseID}',
        );
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    } catch (e) {
      appLogger.error('[AppPurchase] Error finalizing purchase: $e', e);
    } finally {
      _pendingPlanId = null;
      _isRestoreFlow = false;
    }
  }

  void _updateStreamOnDone() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _updateStreamOnError(Object error) {
    appLogger.error('[AppPurchase] Purchase stream error: $error');
    _onError?.call(error.toString());
  }

  ProductDetails? _normalizePlan(String planId) {
    final plan = planId.split('-').first;
    appLogger.info('[AppPurchase] Normalizing planId: $planId to plan: $plan');
    for (final sku in _subscriptionSku) {
      final subId = sku.id.split('_').first;
      if (subId == plan) {
        return sku;
      }
    }
    appLogger.error(
      '[AppPurchase] No matching product found for planId: $planId _subscriptionSku length: ${_subscriptionSku.length}',
    );
    return null;
  }

  /// Apple sends purchase updates for previously purchased items when the app
  /// starts. Only fresh backend state is trusted here so we don't complete a
  /// pending StoreKit transaction based on stale cached account data.
  Future<bool> _checkIfAlreadyPurchased() async {
    final lanternService = sl<LanternPlatformService>();

    final fetchResult = await lanternService.fetchUserData();
    final user = fetchResult.fold((failure) {
      appLogger.warning(
        '[AppPurchase] Failed to fetch latest user data for purchase check: ${failure.error}',
      );
      return null;
    }, (user) => user);

    if (user == null) {
      return false;
    }

    return _userHasActivePurchase(user);
  }

  bool _userHasActivePurchase(UserResponseModel user) {
    final userLevel = user.legacyUserData.userLevel.toLowerCase();
    final subscriptionStatus = user.legacyUserData.subscriptionData.status
        .toLowerCase();
    return userLevel == 'pro' || subscriptionStatus == 'active';
  }

  /// Determines the plan id to send to the backend for acknowledgment.
  ///
  /// Prefers the exact plan the user selected, then falls back to a default.
  Future<String> _resolvePlanId(PurchaseDetails purchase) async {
    if (_pendingPlanId != null && _pendingPlanId!.isNotEmpty) {
      return _pendingPlanId!;
    }

    final pendingPlan = await _pendingPlanForPurchase(purchase);
    if (pendingPlan != null) {
      appLogger.info(
        '[AppPurchase] Resolved plan from pending purchase metadata: $pendingPlan',
      );
      return pendingPlan;
    }

    final prefix = purchase.productID.split('_').first; // "1y" or "1m"
    final localPlans = sl<LocalStorageService>().getPlans();
    if (localPlans != null) {
      for (final plan in localPlans.plans) {
        if (plan.id.startsWith('$prefix-')) {
          appLogger.info('[AppPurchase] Resolved plan from cache: ${plan.id}');
          return plan.id;
        }
      }
    }

    appLogger.debug(
      '[AppPurchase] No cached plan for prefix=$prefix, using default',
    );
    return '$prefix-usd-10';
  }

  void clearCallbacks() {
    _onSuccess = null;
    _onError = null;
    _pendingPlanId = null;
    _isRestoreFlow = false;
  }

  Future<void> _acknowledgePurchase(
    PurchaseDetails purchaseDetails, {
    required String planId,
    bool isRetry = false,
  }) async {
    final key = _purchaseRetryKey(purchaseDetails);
    if (!_acknowledgeInFlight.add(key)) {
      appLogger.info(
        '[AppPurchase] Acknowledgment already in flight: '
        'productID=${purchaseDetails.productID} key=$key',
      );
      return;
    }

    try {
      final purchaseToken =
          purchaseDetails.verificationData.serverVerificationData;
      appLogger.info(
        '[AppPurchase] Acknowledgment ${isRetry ? 'retry' : 'start'}: '
        'productID=${purchaseDetails.productID} '
        'purchaseID=${purchaseDetails.purchaseID} '
        'planId=$planId receiptLength=${purchaseToken.length}',
      );

      if (purchaseToken.isEmpty) {
        await _handleAcknowledgeFailure(
          purchaseDetails,
          'Missing purchase receipt',
          isRetry: isRetry,
        );
        return;
      }

      final lanternService = sl<LanternPlatformService>();
      final ack = await lanternService.acknowledgeInAppPurchase(
        purchaseToken: purchaseToken,
        planId: planId,
      );

      await ack.fold(
        (error) async {
          await _handleAcknowledgeFailure(
            purchaseDetails,
            error,
            isRetry: isRetry,
          );
        },
        (success) async {
          appLogger.info(
            '[AppPurchase] Acknowledgment successful: '
            'productID=${purchaseDetails.productID} purchaseID=${purchaseDetails.purchaseID}',
          );
          _clearAcknowledgeRetry(key);
          await _forgetPendingPlan(purchaseDetails);
          await _finalize(purchaseDetails);
          if (!isRetry) {
            _onSuccess?.call(purchaseDetails);
          }
        },
      );
    } finally {
      _acknowledgeInFlight.remove(key);
    }
  }

  Future<void> _handleAcknowledgeFailure(
    PurchaseDetails purchaseDetails,
    Object error, {
    bool isRetry = false,
    StackTrace? stackTrace,
  }) async {
    appLogger.error(
      '[AppPurchase] Acknowledgment failed; leaving store transaction pending '
      'for retry: productID=${purchaseDetails.productID} '
      'purchaseID=${purchaseDetails.purchaseID}',
      error,
      stackTrace,
    );

    if (await _checkIfAlreadyPurchased()) {
      appLogger.info(
        '[AppPurchase] Account is already active after acknowledgment failure; '
        'finalizing store transaction',
      );
      _clearAcknowledgeRetry(_purchaseRetryKey(purchaseDetails));
      await _forgetPendingPlan(purchaseDetails);
      await _finalize(purchaseDetails);
      if (!isRetry) {
        _onSuccess?.call(purchaseDetails);
      }
      return;
    }

    if (!isRetry) {
      final onError = _onError;
      _onSuccess = null;
      _onError = null;
      _pendingPlanId = null;
      onError?.call(
        'Purchase verification failed. We will retry in the background.',
      );
    }
    _scheduleAcknowledgeRetry(purchaseDetails);
  }

  void _scheduleAcknowledgeRetry(PurchaseDetails purchaseDetails) {
    final key = _purchaseRetryKey(purchaseDetails);
    if (_ackRetryTimers.containsKey(key)) {
      appLogger.info(
        '[AppPurchase] Acknowledgment retry already scheduled: '
        'productID=${purchaseDetails.productID} key=$key',
      );
      return;
    }

    final attempt = _ackRetryAttempts[key] ?? 0;
    final delay = _ackRetryDelayForAttempt(attempt);
    appLogger.info(
      '[AppPurchase] Scheduling acknowledgment retry ${attempt + 1} in $delay: '
      'productID=${purchaseDetails.productID} purchaseID=${purchaseDetails.purchaseID}',
    );

    _ackRetryTimers[key] = Timer(delay, () {
      unawaited(() async {
        try {
          final planId = await _resolvePlanId(purchaseDetails);
          _ackRetryTimers.remove(key);
          _ackRetryAttempts[key] = (_ackRetryAttempts[key] ?? 0) + 1;
          await _acknowledgePurchase(
            purchaseDetails,
            planId: planId,
            isRetry: true,
          );
        } catch (e, st) {
          _ackRetryTimers.remove(key);
          await _handleAcknowledgeFailure(
            purchaseDetails,
            e,
            isRetry: true,
            stackTrace: st,
          );
        }
      }());
    });
  }

  Duration _ackRetryDelayForAttempt(int attempt) {
    final index = attempt >= _ackRetryDelays.length
        ? _ackRetryDelays.length - 1
        : attempt;
    return _ackRetryDelays[index];
  }

  void _clearAcknowledgeRetry(String key) {
    _ackRetryAttempts.remove(key);
    _ackRetryTimers.remove(key)?.cancel();
  }

  String _purchaseRetryKey(PurchaseDetails purchase) {
    final transactionKey = _transactionPlanKey(purchase);
    if (transactionKey != null) {
      return transactionKey;
    }
    return _productPlanKey(purchase.productID);
  }

  String _productPlanKey(String productID) =>
      '$_productPlanKeyPrefix$productID';

  String? _transactionPlanKey(PurchaseDetails purchase) {
    final purchaseID = purchase.purchaseID;
    if (purchaseID != null && purchaseID.isNotEmpty) {
      return '$_transactionPlanKeyPrefix$purchaseID';
    }
    final transactionDate = purchase.transactionDate;
    if (transactionDate != null && transactionDate.isNotEmpty) {
      return '$_transactionPlanKeyPrefix${purchase.productID}:$transactionDate';
    }
    return null;
  }

  List<String> _planKeysForPurchase(PurchaseDetails purchase) {
    final transactionKey = _transactionPlanKey(purchase);
    final keys = <String>[_productPlanKey(purchase.productID)];
    if (transactionKey != null) {
      keys.insert(0, transactionKey);
    }
    return keys;
  }

  Future<String?> _pendingPlanForPurchase(PurchaseDetails purchase) async {
    final pending = await _loadPendingPurchasePlans();
    for (final key in _planKeysForPurchase(purchase)) {
      final planId = pending[key];
      if (planId != null && planId.isNotEmpty) {
        return planId;
      }
    }
    return null;
  }

  Future<void> _rememberPendingPlanForProduct(
    String productID,
    String planId,
  ) async {
    if (planId.isEmpty) {
      return;
    }
    final pending = await _loadPendingPurchasePlans();
    pending[_productPlanKey(productID)] = planId;
    await _savePendingPurchasePlans(pending);
    appLogger.info(
      '[AppPurchase] Stored pending purchase plan: productID=$productID planId=$planId',
    );
  }

  Future<void> _rememberPendingPlanForPurchase(
    PurchaseDetails purchase,
    String planId,
  ) async {
    if (planId.isEmpty) {
      return;
    }
    final pending = await _loadPendingPurchasePlans();
    for (final key in _planKeysForPurchase(purchase)) {
      pending[key] = planId;
    }
    await _savePendingPurchasePlans(pending);
    appLogger.info(
      '[AppPurchase] Stored pending purchase plan: '
      'productID=${purchase.productID} purchaseID=${purchase.purchaseID} planId=$planId',
    );
  }

  Future<void> _forgetPendingPlan(PurchaseDetails purchase) async {
    final pending = await _loadPendingPurchasePlans();
    var changed = false;
    for (final key in _planKeysForPurchase(purchase)) {
      changed = pending.remove(key) != null || changed;
    }
    if (changed) {
      await _savePendingPurchasePlans(pending);
      appLogger.info(
        '[AppPurchase] Cleared pending purchase plan: '
        'productID=${purchase.productID} purchaseID=${purchase.purchaseID}',
      );
    }
  }

  Future<void> _forgetPendingPlanForProduct(String productID) async {
    final pending = await _loadPendingPurchasePlans();
    if (pending.remove(_productPlanKey(productID)) != null) {
      await _savePendingPurchasePlans(pending);
      appLogger.info(
        '[AppPurchase] Cleared pending purchase plan for productID=$productID',
      );
    }
  }

  Future<Map<String, String>> _loadPendingPurchasePlans() async {
    final storage = sl<LocalStorageService>();
    final raw = storage.getString(_pendingPurchasePlansKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
      appLogger.warning('Pending purchase plans had invalid shape; clearing');
    } catch (e, st) {
      appLogger.error(
        'Failed to parse pending purchase plans; clearing',
        e,
        st,
      );
    }
    await storage.remove(_pendingPurchasePlansKey);
    return {};
  }

  Future<void> _savePendingPurchasePlans(Map<String, String> pending) async {
    final storage = sl<LocalStorageService>();
    if (pending.isEmpty) {
      await storage.remove(_pendingPurchasePlansKey);
      return;
    }
    await storage.setString(_pendingPurchasePlansKey, jsonEncode(pending));
  }
}
