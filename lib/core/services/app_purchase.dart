import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/mapper/plan_mapper.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

import '../models/plan_data.dart';
import 'injection_container.dart' show sl;

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

  void init() {
    if (PlatformUtils.isDesktop) {
      return;
    }

    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdates,
      onDone: _updateStreamOnDone,
      onError: _updateStreamOnError,
    );

    unawaited(fetchSubscriptions());
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

        final response =
            await _inAppPurchase.queryProductDetails(_subscriptionIds.toSet());

        if (response.error != null) {
          appLogger.error('[AppPurchase] Error fetching subscriptions: ${response.error}');
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
          appLogger
              .info('[AppPurchase] Fetched subscriptions: ${_subscriptionSku.length} items');
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

    // All attempts exhausted without success.
    _productsLoadedCompleter!.completeError(
      StateError(
          'Unable to load App Store products after $maxAttempts attempts'),
    );
  }

  /// Ensures products are available before starting a purchase.
  ///
  /// If products aren't loaded yet, waits for the in-flight fetch or kicks off
  /// a new one. Times out to avoid hanging the UI forever.
  Future<void> _waitForProducts() async {
    if (_productsLoaded) return;

    // If there's no active fetch (or it finished), start one
    if (_productsLoadedCompleter == null ||
        _productsLoadedCompleter!.isCompleted) {
      _productsLoadedCompleter = Completer<void>();
      unawaited(fetchSubscriptions());
    }

    // Wait for completion (or error)
    await _productsLoadedCompleter!.future;
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

    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      final started =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) {
        _onError?.call("Failed to initiate purchase flow.");
      }
    } catch (e) {
      _onError?.call("Error starting subscription: $e");
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    appLogger.info('[AppPurchase] Received purchase updates: ${purchases.length}');
    for (final purchase in purchases) {
      await _handlePurchase(purchase);
    }
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
        /// User has cancelled the purchase
        if (PlatformUtils.isIOS) {
          /// iOS specific handling
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        _onError?.call("Purchase canceled");
        return;
      }
      if (status == PurchaseStatus.purchased ||
          status == PurchaseStatus.restored) {
        /// Apple sends purchase updates for previously purchased items when the app starts.
        /// This check prevents processing the same subscription multiple times.
        if (_checkIfAlreadyPurchased()) {
          appLogger.info(
            '[AppPurchase] User has already purchased the subscription. Finalizing purchase without processing.',
          );
          await _finalize(purchaseDetails);
          _onError?.call('You have already purchased this subscription.');
          return;
        }

        try {
          appLogger.info('[AppPurchase] Purchase successful: ${purchaseDetails.productID}');
          final lanternService = sl<LanternPlatformService>();
          final purchaseToken =
              purchaseDetails.verificationData.serverVerificationData;
          final planId = _resolvePlanId(purchaseDetails);

          appLogger.info('[AppPurchase] Acknowledging purchase with planId: $planId');
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
      appLogger.error('[AppPurchase] Error handling purchase: $e');
      _onError?.call(e.toString());
    }
  }

  // Separate helper to ensure the Store is cleared
  Future<void> _finalize(PurchaseDetails purchaseDetails) async {
    try {
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    } finally {
      _pendingPlanId = null;
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
  bool _checkIfAlreadyPurchased() {
    final user = sl<LocalStorageService>().getUser();
    if (user?.legacyUserData != null) {
      final legacyData = user!.legacyUserData;
      final subscriptionStatus = legacyData.subscriptionData.status;
      if (subscriptionStatus == 'active') {
        return true;
      }
      return false;
    }

    return false;
  }

  /// Determines the plan id to send to the backend for acknowledgment.
  ///
  /// Prefers the exact plan the user selected. Falls back to cached plans,
  /// then to a sensible default.
  String _resolvePlanId(PurchaseDetails purchase) {
    if (_pendingPlanId != null && _pendingPlanId!.isNotEmpty) {
      return _pendingPlanId!;
    }

    // Fallback: try to find a matching cached plan.
    final prefix = purchase.productID.split('_').first; // "1y" or "1m"
    final localPlans = sl<LocalStorageService>().getPlans()?.toPlanData();

    if (localPlans != null) {
      final match = localPlans.plans.cast<Plan?>().firstWhere(
            (p) => (p?.id)?.startsWith('$prefix-') ?? false,
            orElse: () => null,
          );
      if (match != null) {
        appLogger.info(
          '[AppPurchase] Resolved plan from cache: ${match.id}',
        );
        return match.id;
      }
    }
    // Last resort fallback.
    appLogger.debug(
      '[AppPurchase] No cached plan for prefix=$prefix, using default',
    );
    return '$prefix-usd-10';
  }

  void clearCallbacks() {
    _onSuccess = null;
    _onError = null;
    _pendingPlanId = null;
  }
}
