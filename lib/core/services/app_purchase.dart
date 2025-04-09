import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/error.dart';

typedef PaymentSuccessCallback = void Function(PurchaseDetails purchase);
typedef PaymentErrorCallback = void Function(String error);

class AppPurchase {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final List<ProductDetails> _subscriptionSku = [];
  final List<String> _subscriptionIds = <String>['1m_sub', '1y_sub'];

  PaymentSuccessCallback? _onSuccess;
  PaymentErrorCallback? _onError;

  void init() {
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdates,
      onDone: _updateStreamOnDone,
      onError: _updateStreamOnError,
    );
    fetchSubscriptions();
  }

  Future<void> fetchSubscriptions({int attempt = 0}) async {
    try {
      final response =
          await _inAppPurchase.queryProductDetails(_subscriptionIds.toSet());
      if (response.error != null) {
        appLogger.error('Error fetching subscriptions: ${response.error}');
        if (attempt < 2) {
          // Retry fetching subscriptions if there's an error
          appLogger.info('Retrying to fetch subscriptions, attempt: $attempt');
          fetchSubscriptions(attempt: attempt + 1);
          return;
        }
        return;
      }
      _subscriptionSku.clear();
      _subscriptionSku.addAll(response.productDetails);
    } catch (e) {
      appLogger.error('Error fetching subscriptions: $e');
      if (attempt < 2) {
        appLogger.info('Retrying to fetch subscriptions, attempt: $attempt');
        fetchSubscriptions(attempt: attempt + 1);
      }
    }
  }

  Future<bool> isAvailable() async {
    return await InAppPurchase.instance.isAvailable();
  }

  /// Starts the subscription flow and only triggers the callbacks related to this purchase.
  Future<void> startSubscription({
    required String plan,
    required void Function(PurchaseDetails purchase) onSuccess,
    required void Function(String error) onError,
  }) async {
    _onSuccess = onSuccess;
    _onError = onError;

    final purchaseParam = PurchaseParam(productDetails: _subscriptionSku.first);
    try {
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

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    appLogger.info('Purchase updates: $purchases');
    for (final purchase in purchases) {
      await _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    appLogger.info('Handling purchase: ${purchaseDetails.status}');

    try {
      final status = purchaseDetails.status;

      if (status == PurchaseStatus.error) {
        /// Error occurred during purchase
        appLogger.error('Purchase error: ${purchaseDetails.error}');
        if (PlatformUtils.isIOS()) {
          /// iOS specific handling
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        _onError?.call(purchaseDetails.error?.message.localizedDescription ??
            "Unknown error");
        /// User has cancelled the purchase

        return;
      }
      if (status == PurchaseStatus.canceled) {
        /// User has cancelled the purchase
        if (PlatformUtils.isIOS()) {
          /// iOS specific handling
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
        _onError?.call("Purchase canceled");
        return;
      }
      if (status == PurchaseStatus.purchased) {
        ///Verify the purchase
        await _inAppPurchase.completePurchase(purchaseDetails);
        _onSuccess?.call(purchaseDetails);
        return;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
      }
    } catch (e) {
      appLogger.error('Error handling purchase: $e');
      _onError?.call(e.toString());
    }
  }

  void _updateStreamOnDone() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _updateStreamOnError(Object error) {
    appLogger.error('Purchase stream error: $error');
    _onError?.call(error.toString());
  }
}
