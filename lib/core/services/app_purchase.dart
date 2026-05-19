import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

import 'injection_container.dart' show sl;
import 'local_storage_service.dart';

typedef PaymentSuccessCallback = void Function(PurchaseDetails purchase);
typedef PaymentErrorCallback = void Function(String error);

class AppPurchase {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final List<ProductDetails> _subscriptionSku = [];
  final List<String> _subscriptionIds = <String>['1m_sub', '1y_sub'];

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
    if (PlatformUtils.isDesktop || _subscription != null) {
      return;
    }
    // Subscribing to purchaseStream initializes BillingClient, which OOMs
    // the Dalvik heap via an internal reconnect loop when Play Billing
    // isn't reachable. See getlantern/engineering#3485.
    if (Platform.isAndroid && !isStoreVersion()) {
      return;
    }

    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
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

    /// All retries exhausted. On Android, treat this as a strong signal that
    /// Google Play Billing is unreachable (typical in CN/RU/IR even when the
    /// ipinfo.io country lookup itself is blocked) and flip the censored-region
    /// flag so isStoreVersion() routes the user to the Stripe flow.
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
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!started) {
        _onError?.call("Failed to initiate purchase flow.");
      }
    } catch (e) {
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
          await _finalize(purchaseDetails);
          _onError?.call('You have already purchased this subscription.');
          return;
        }

        try {
          appLogger.info(
            '[AppPurchase] Purchase successful: ${purchaseDetails.productID}',
          );
          final lanternService = sl<LanternPlatformService>();
          final purchaseToken =
              purchaseDetails.verificationData.serverVerificationData;
          final planId = _resolvePlanId(purchaseDetails);

          appLogger.info(
            '[AppPurchase] Acknowledging purchase with planId: $planId',
          );
          final ack = await lanternService.acknowledgeInAppPurchase(
            purchaseToken: purchaseToken,
            planId: planId,
          );
          ack.fold(
            (error) {
              appLogger.error('[AppPurchase] Acknowledgment failed: $error');
              _finalize(purchaseDetails);
              _onError?.call('Purchase acknowledgment failed: $error');
            },
            (success) async {
              appLogger.info('[AppPurchase] Acknowledgment successful');
              _finalize(purchaseDetails);
              _onSuccess?.call(purchaseDetails);
            },
          );
        } catch (e) {
          _onError?.call('Error during purchase acknowledgment: $e');
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

  /// Apple sends purchase updates for previously purchased items when the
  /// app starts. This function checks if the user has already purchased the
  /// subscription to avoid duplicate processing
  Future<bool> _checkIfAlreadyPurchased() async {
    final lanternService = sl<LanternPlatformService>();

    final fetchResult = await lanternService.fetchUserData();
    final fetchedUser = fetchResult.fold((failure) {
      appLogger.warning(
        '[AppPurchase] Failed to fetch latest user data for purchase check: ${failure.error}',
      );
      return null;
    }, (user) => user);

    final user =
        fetchedUser ??
        (await lanternService.getUserData()).fold((failure) {
          appLogger.warning(
            '[AppPurchase] Failed to load cached user data for purchase check: ${failure.error}',
          );
          return null;
        }, (user) => user);

    if (user == null) {
      return false;
    }

    final userLevel = user.legacyUserData.userLevel.toLowerCase();
    final subscriptionStatus = user.legacyUserData.subscriptionData.status
        .toLowerCase();

    return userLevel == 'pro' || subscriptionStatus == 'active';
  }

  /// Determines the plan id to send to the backend for acknowledgment.
  ///
  /// Prefers the exact plan the user selected, then falls back to a default.
  String _resolvePlanId(PurchaseDetails purchase) {
    if (_pendingPlanId != null && _pendingPlanId!.isNotEmpty) {
      return _pendingPlanId!;
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
}
