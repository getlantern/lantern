import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/user.dart';
import 'package:lantern/core/services/purchase/pending_purchase_store.dart';
import 'package:lantern/core/services/purchase/purchase_acknowledger.dart';
import 'package:lantern/core/utils/country_code.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';

import 'injection_container.dart' show sl;
import 'local_storage_service.dart';

typedef PaymentSuccessCallback = void Function(PurchaseDetails purchase);
typedef PaymentErrorCallback = void Function(String error);

/// Mutable state of the in-progress purchase/restore flow, grouped so the
/// callbacks and pending selections have a single home and reset point.
class _PurchaseSession {
  PaymentSuccessCallback? onSuccess;
  PaymentErrorCallback? onError;

  /// The exact plan id the user chose (e.g. "1y-usd-10").
  String? pendingPlanId;

  /// Affiliate code applied at purchase start; forwarded to the backend for
  /// attribution. Empty when none.
  String pendingCouponCode = '';

  bool isRestoreFlow = false;

  /// Set once a restored receipt arrives, so iOS can detect "nothing to
  /// restore" (StoreKit emits no empty-stream event the way Play Billing does).
  bool restoreReceivedAny = false;
}

class AppPurchase {
  /// [inAppPurchase], [pendingStore] and [acknowledger] are injectable for
  /// tests; production uses the store plugin singleton and the service locator.
  AppPurchase({
    InAppPurchase? inAppPurchase,
    PendingPurchaseStore? pendingStore,
    PurchaseAcknowledger? acknowledger,
  }) : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance {
    _pendingStore =
        pendingStore ?? PendingPurchaseStore(() => sl<LocalStorageService>());
    _acknowledger =
        acknowledger ??
        PurchaseAcknowledger(
          acknowledgeReceipt:
              ({
                required String purchaseToken,
                required String planId,
                required String couponCode,
              }) => sl<LanternPlatformService>().acknowledgeInAppPurchase(
                purchaseToken: purchaseToken,
                planId: planId,
                couponCode: couponCode,
              ),
          resolvePlanId: _resolvePlanId,
          resolveCouponCode: _resolveCouponCode,
          retryKeyFor: (purchase) => _pendingStore.retryKeyFor(purchase),
          isAlreadyActive: _checkIfAlreadyPurchased,
          onAcknowledged: _onAcknowledged,
        );
  }

  final InAppPurchase _inAppPurchase;
  late final PendingPurchaseStore _pendingStore;
  late final PurchaseAcknowledger _acknowledger;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final List<ProductDetails> _subscriptionSku = [];
  final List<String> _subscriptionIds = <String>['1m_sub', '1y_sub'];

  // iOS-only affiliate SKUs. Each mirrors a base plan but carries an
  // introductory offer configured in App Store Connect, and is only ever
  // surfaced once an affiliate/referral code is applied. StoreKit has no
  // per-offer concept, so the discount has to live on a dedicated product;
  // Android instead exposes the discount as a Play Console offer on the base
  // product, so these are never queried there.
  static const List<String> _iosAffiliateIds = <String>[
    '1m_sub_affiliate',
    '1y_sub_affiliate',
  ];

  bool _productsLoaded = false;
  Completer<void>? _productsLoadedCompleter;

  final _PurchaseSession _session = _PurchaseSession();

  /// Starts listening for store purchase updates without fetching product
  /// details. Product lookup stays user-initiated to keep StoreKit out of the
  /// normal app launch path on iOS.
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

  Future<bool> _ensurePurchaseStreamReady() async {
    appLogger.info(
      '[AppPurchase] _ensurePurchaseStreamReady: '
      'country=${CountryCode.current}, isKnown=${CountryCode.isKnown}, '
      'subscribed=${_subscription != null}',
    );
    init();
    if (_subscription != null) {
      appLogger.info('[AppPurchase] _ensurePurchaseStreamReady: ready');
      return true;
    }
    if (Platform.isAndroid && !CountryCode.isKnown) {
      appLogger.info(
        '[AppPurchase] _ensurePurchaseStreamReady: country unknown, '
        'waiting for country-code event…',
      );
      final known = await CountryCode.waitUntilKnown();
      appLogger.info(
        '[AppPurchase] _ensurePurchaseStreamReady: waitUntilKnown returned '
        '$known (country=${CountryCode.current}); retrying init',
      );
      init();
    }
    final ready = _subscription != null;
    appLogger.info('[AppPurchase] _ensurePurchaseStreamReady: ready=$ready');
    return ready;
  }

  /// The product IDs to query from the store. iOS additionally queries the
  /// dedicated affiliate SKUs (see [_iosAffiliateIds]); [_selectSkus] then
  /// keeps whichever set matches the requested mode. Android never queries
  /// them because its discount is an offer on the base product.
  Set<String> get _productIdsToQuery => <String>{
    ..._subscriptionIds,
    if (Platform.isIOS) ..._iosAffiliateIds,
  };

  /// Loads the subscription SKUs to purchase from.
  ///
  /// By default only base plans are kept ([includeOffers] false), so the first
  /// fetch never charges a promotional offer. After a referral/affiliate code
  /// is applied, call again with [includeOffers] true to load only the offer
  /// SKUs — then the discounted offer is what gets charged. Either way
  /// [_normalizePlan] just matches by plan prefix, so the rest of the purchase
  /// logic is identical for plans and offers.
  Future<void> fetchSubscriptions({
    bool includeOffers = false,
    int maxAttempts = 3,
  }) async {
    // Piggy-back only on a fetch that's still running; a completed one must
    // re-run so the SKU set can switch between base plans and offers.
    final inFlight = _productsLoadedCompleter;
    if (inFlight != null && !inFlight.isCompleted) {
      return inFlight.future;
    }
    _productsLoaded = false;
    final completer = Completer<void>();
    _productsLoadedCompleter = completer;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        appLogger.info(
          '[AppPurchase] Fetching subscriptions (includeOffers=$includeOffers), '
          'attempt: ${attempt + 1}/$maxAttempts',
        );

        final response = await _inAppPurchase.queryProductDetails(
          _productIdsToQuery,
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
          final products = _selectSkus(
            response.productDetails,
            includeOffers: includeOffers,
          );
          appLogger.info(
            '[AppPurchase] Fetched ${response.productDetails.length} '
            'subscriptions, ${products.length} match '
            '(includeOffers=$includeOffers)',
          );
          if (products.isNotEmpty) {
            _subscriptionSku
              ..clear()
              ..addAll(products);
            _productsLoaded = true;
            if (!completer.isCompleted) completer.complete();
            return;
          }

          // The store is reachable and returned SKUs, but none matched the
          // requested set (e.g. offers requested but none are active).
          // Retrying the same query won't change that, and this isn't a
          // Play-unreachable signal, so fail fast without marking the region
          // censored. Callers fall back to the base-plan fetch.
          final error = StateError(
            'No ${includeOffers ? 'offer' : 'base plan'} SKUs available',
          );
          if (!completer.isCompleted) completer.completeError(error);
          throw error;
        }
      } on StateError {
        rethrow;
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
      'Unable to load in-app purchase products after $maxAttempts attempts',
    );
    if (!completer.isCompleted) completer.completeError(error);
    throw error;
  }

  /// The loaded store product matching [planId]'s plan family ("1m…" → the
  /// monthly SKU), or null when products aren't loaded or nothing matches.
  ProductDetails? storeProductFor(String planId) {
    final prefix = _planPrefix(planId);
    for (final sku in _subscriptionSku) {
      if (_planPrefix(sku.id) == prefix) {
        return sku;
      }
    }
    return null;
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
    String couponCode = '',
  }) async {
    _session.onSuccess = onSuccess;
    _session.onError = onError;
    // Store the exact plan id user chose (ex: "1y-usd-10")
    _session.pendingPlanId = plan;
    // Capture the applied affiliate/referral code so it can be sent with the
    // acknowledgment. Reset to '' when none so a prior purchase's code never
    // leaks into an unrelated one.
    _session.pendingCouponCode = couponCode;

    if (!await _ensurePurchaseStreamReady()) {
      _session.onError?.call(
        "Unable to access in-app purchases. Check your network and try again.",
      );
      return;
    }

    try {
      await _waitForProducts();
    } catch (_) {
      _session.onError?.call(
        "Unable to load in-app purchase products. Check your network and try again.",
      );
      return;
    }

    final product = _normalizePlan(plan);
    if (product == null) {
      _session.onError?.call("Invalid plan: $plan");
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
        '[AppPurchase] Initiating purchase for product: ${product.id} with pendingPlanId: ${_session.pendingPlanId}',
      );
      await _pendingStore.rememberForProduct(
        product.id,
        planId: plan,
        couponCode: couponCode,
      );
      final started = await _inAppPurchase.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!started) {
        await _pendingStore.forgetProduct(product.id);
        _session.onError?.call("Failed to initiate purchase flow.");
      }
    } catch (e) {
      await _pendingStore.forgetProduct(product.id);
      _session.onError?.call("Error starting subscription: $e");
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
    _session.onSuccess = onSuccess;
    _session.onError = onError;
    _session.isRestoreFlow = true;
    _session.restoreReceivedAny = false;
    _session.pendingPlanId = null;
    _session.pendingCouponCode = '';

    if (!await _ensurePurchaseStreamReady()) {
      _session.isRestoreFlow = false;
      final onError = _session.onError;
      clearCallbacks();
      onError?.call(
        "Unable to access in-app purchases. Check your network and try again.",
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
          if (_session.isRestoreFlow && !_session.restoreReceivedAny) {
            appLogger.info('[AppPurchase] iOS restore: no purchases delivered');
            _session.isRestoreFlow = false;
            final onError = _session.onError;
            clearCallbacks();
            onError?.call('No previous purchases found to restore.');
          }
        });
      }
    } catch (e, st) {
      appLogger.error('[AppPurchase] Error restoring purchases', e, st);
      _session.isRestoreFlow = false;
      final onError = _session.onError;
      clearCallbacks();
      onError?.call('Error restoring purchases: $e');
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    appLogger.info(
      '[AppPurchase] Received purchase updates: ${purchases.length}',
    );
    if (_session.isRestoreFlow && purchases.isEmpty) {
      appLogger.info(
        '[AppPurchase] Restore flow: purchase stream emitted empty list',
      );
      _session.isRestoreFlow = false;
      final onError = _session.onError;
      clearCallbacks();
      onError?.call('No previous purchases found to restore.');
      return;
    }

    /// During restore, if more than one restored receipt comes back, batch
    /// them: pick one to surface and finalize the rest. Otherwise _finalize
    /// would clear isRestoreFlow after the first item and the second
    /// iteration would fall into the regular acknowledge path.
    if (_session.isRestoreFlow && purchases.length > 1) {
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
  /// with the store, and fires `onSuccess` once.
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

    _session.restoreReceivedAny = true;

    // Complete each receipt inline (don't call _finalize — its `finally`
    // clears isRestoreFlow, which would mis-route any re-entrant stream
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

    final onSuccess = _session.onSuccess;
    _session.isRestoreFlow = false;
    _session.pendingPlanId = null;
    clearCallbacks();
    onSuccess?.call(chosen);
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    appLogger.info(
      '[AppPurchase] Handling purchase: ${purchaseDetails.productID} with status: ${purchaseDetails.status}',
    );
    try {
      switch (purchaseDetails.status) {
        case PurchaseStatus.error:
          await _handlePurchaseError(purchaseDetails);
        case PurchaseStatus.canceled:
          await _handlePurchaseCanceled(purchaseDetails);
        case PurchaseStatus.pending:
          _handlePurchasePending(purchaseDetails);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleCompletedPurchase(purchaseDetails);
      }
    } catch (e) {
      appLogger.error('[AppPurchase] Error handling purchase: $e', e);
      // Capture-clear-fire: clear the session before surfacing the error so a
      // stale onSuccess/onError can't fire again when Apple re-delivers this
      // pending transaction on the next launch (matches the restore paths).
      final onError = _session.onError;
      clearCallbacks();
      onError?.call(e.toString());
    }
  }

  Future<void> _handlePurchaseError(PurchaseDetails purchase) async {
    appLogger.error('Purchase error: ${purchase.error}');
    final errorMessage = purchase.error?.message ?? 'Unknown error';
    await _pendingStore.forgetPurchase(purchase);
    _session.pendingPlanId = null;
    _session.onError?.call(errorMessage);
  }

  Future<void> _handlePurchaseCanceled(PurchaseDetails purchase) async {
    // `canceled` is not necessarily a real user cancel — the in_app_purchase
    // plugin also maps several silent Google Play rejections (offer
    // ineligibility, missing payment method, region mismatch, billing-service
    // hiccups) to the same status. Without capturing the underlying error we
    // can't distinguish those from a user who actually X'd the dialog, which is
    // the difference between "expected" and "a bug to fix." For Android,
    // `error.details` typically contains a Map with the raw BillingClient
    // `response_code` and `debug_message`.
    appLogger.info(
      '[AppPurchase] Purchase canceled: productID=${purchase.productID}'
      ' errorCode=${purchase.error?.code}'
      ' message=${purchase.error?.message}'
      ' details=${purchase.error?.details}',
    );
    await _pendingStore.forgetPurchase(purchase);
    _session.pendingPlanId = null;
    _session.onError?.call('Purchase canceled');
  }

  void _handlePurchasePending(PurchaseDetails purchase) {
    // Deferred payment method (e.g. on Android): the purchase completes
    // asynchronously when the payment is confirmed; just inform the user.
    appLogger.info('[AppPurchase] Purchase is pending: ${purchase.productID}');
    _session.onError?.call(
      'Purchase is pending. You will be notified when it completes.',
    );
  }

  /// Handles a `purchased`/`restored` receipt: during an explicit restore just
  /// finalize and report success; otherwise verify it with the backend (unless
  /// the account is already active) through the acknowledger.
  Future<void> _handleCompletedPurchase(PurchaseDetails purchase) async {
    if (_session.isRestoreFlow) {
      appLogger.info('[AppPurchase] Found restore purchase calling success');
      _session.restoreReceivedAny = true;
      await _finalize(purchase);
      final onSuccess = _session.onSuccess;
      clearCallbacks();
      onSuccess?.call(purchase);
      return;
    }

    // Apple re-delivers previously purchased items at launch; trust fresh
    // backend state so the same subscription isn't processed twice.
    if (await _checkIfAlreadyPurchased()) {
      appLogger.info(
        '[AppPurchase] User has already purchased the subscription. '
        'Finalizing purchase without processing.',
      );
      await _pendingStore.forgetPurchase(purchase);
      await _finalize(purchase);
      _session.onError?.call('You have already purchased this subscription.');
      return;
    }

    appLogger.info('[AppPurchase] Purchase successful: ${purchase.productID}');
    final planId = await _resolvePlanId(purchase);
    final couponCode = await _resolveCouponCode(purchase);
    await _pendingStore.rememberForPurchase(
      purchase,
      planId: planId,
      couponCode: couponCode,
    );
    await _acknowledger.acknowledge(
      purchase,
      planId: planId,
      couponCode: couponCode,
      onSuccess: _onAckSuccess,
      onError: _onAckError,
    );
  }

  void _onAckSuccess(PurchaseDetails purchase) =>
      _session.onSuccess?.call(purchase);

  /// Surfaces the "will retry in the background" message and clears the
  /// in-memory session, so a later background retry resolves the plan from
  /// persisted metadata and a stray success can't fire the now-stale callback.
  void _onAckError(String message) {
    final onError = _session.onError;
    _session.onSuccess = null;
    _session.onError = null;
    _session.pendingPlanId = null;
    onError?.call(message);
  }

  /// Runs once the backend confirms a purchase (or the account is found already
  /// active): drop its pending metadata and complete the store transaction.
  Future<void> _onAcknowledged(PurchaseDetails purchase) async {
    await _pendingStore.forgetPurchase(purchase);
    await _finalize(purchase);
  }

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
      _session.pendingPlanId = null;
      _session.pendingCouponCode = '';
      _session.isRestoreFlow = false;
    }
  }

  void _updateStreamOnDone() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _updateStreamOnError(Object error) {
    appLogger.error('[AppPurchase] Purchase stream error: $error');
    _session.onError?.call(error.toString());
  }

  /// Keeps only the SKUs matching the requested mode.
  ///
  /// On Android each Play Console offer comes back as its own
  /// [GooglePlayProductDetails]: base plans have a null (or empty) offerId,
  /// discount offers have a non-null offerId. When [includeOffers] is false we
  /// keep base plans (a normal purchase), when true we keep only offers (an
  /// applied affiliate/referral discount).
  ///
  /// iOS has no per-offer concept, so the discount lives on a dedicated
  /// affiliate product ([_iosAffiliateIds]). We apply the same split there:
  /// keep only the affiliate SKUs when an offer was requested, otherwise only
  /// the base SKUs. Either way `_subscriptionSku` ends up holding just one set,
  /// so the downstream `_normalizePlan` prefix match resolves unambiguously.
  List<ProductDetails> _selectSkus(
    List<ProductDetails> products, {
    required bool includeOffers,
  }) {
    if (!Platform.isAndroid) {
      return products.where((product) {
        final isAffiliate = _iosAffiliateIds.contains(product.id);
        return includeOffers ? isAffiliate : !isAffiliate;
      }).toList();
    }
    return products.where((product) {
      final offerId = _offerIdFor(product);
      final isOffer = offerId != null && offerId.isNotEmpty;
      return includeOffers ? isOffer : !isOffer;
    }).toList();
  }

  /// The Play Console offerId backing [product], or null when it's a base plan
  /// (or not an Android subscription product).
  String? _offerIdFor(ProductDetails product) {
    if (product is! GooglePlayProductDetails) {
      return null;
    }
    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) {
      return null;
    }
    return offers[index].offerId;
  }

  /// The plan-family prefix shared by a plan id and its store product id:
  /// "1y-usd-10" → "1y", "1y_sub" → "1y", "1y_sub_affiliate" → "1y". Splitting
  /// on either delimiter lets a plan and its (base or affiliate) SKU match.
  static String _planPrefix(String id) => id.split(RegExp('[-_]')).first;

  /// Resolves the store product to purchase for [planId] by matching the plan
  /// prefix (e.g. "1y"). Whether this returns a base plan or a discount offer
  /// depends purely on which SKU set was loaded by [fetchSubscriptions].
  ProductDetails? _normalizePlan(String planId) {
    final plan = _planPrefix(planId);
    appLogger.info('[AppPurchase] Normalizing planId: $planId to plan: $plan');
    for (final sku in _subscriptionSku) {
      if (_planPrefix(sku.id) == plan) {
        return sku;
      }
    }
    appLogger.error(
      '[AppPurchase] No matching product found for planId: $planId '
      '_subscriptionSku length: ${_subscriptionSku.length}',
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

  /// Deliberately wider than [UserDataProX.isPro]: a subscription can read as
  /// active before the account level flips, and wrongly telling someone their
  /// payment failed is worse than being early. Entitlement decisions must still
  /// use isPro — this only gates post-purchase messaging.
  bool _userHasActivePurchase(UserResponseModel user) {
    if (user.legacyUserData.isPro) return true;
    return user.legacyUserData.subscriptionData.status.toLowerCase() ==
        'active';
  }

  /// Determines the plan id to send to the backend for acknowledgment.
  ///
  /// Prefers the exact plan the user selected, then the value persisted for
  /// this purchase (so background retries and post-restart re-delivery still
  /// resolve it), then a cached plan matching the product prefix, then a
  /// default.
  Future<String> _resolvePlanId(PurchaseDetails purchase) async {
    final pendingPlanId = _session.pendingPlanId;
    if (pendingPlanId != null && pendingPlanId.isNotEmpty) {
      return pendingPlanId;
    }

    final pendingPlan = await _pendingStore.planFor(purchase);
    if (pendingPlan != null) {
      appLogger.info(
        '[AppPurchase] Resolved plan from pending purchase metadata: $pendingPlan',
      );
      return pendingPlan;
    }

    final prefix = _planPrefix(purchase.productID); // "1y" or "1m"
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

  /// Resolves the affiliate/referral code to send with acknowledgment.
  ///
  /// Prefers the code captured for the in-flight purchase; falls back to the
  /// value persisted for this purchase so background retries and store
  /// re-delivery after a restart still attribute the sale. Returns '' when no
  /// code was applied.
  Future<String> _resolveCouponCode(PurchaseDetails purchase) async {
    if (_session.pendingCouponCode.isNotEmpty) {
      return _session.pendingCouponCode;
    }
    return await _pendingStore.couponFor(purchase) ?? '';
  }

  void clearCallbacks() {
    _session.onSuccess = null;
    _session.onError = null;
    _session.pendingPlanId = null;
    _session.pendingCouponCode = '';
    _session.isRestoreFlow = false;
  }
}
