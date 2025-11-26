import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payment_notifier.g.dart';

@Riverpod()
class PaymentNotifier extends _$PaymentNotifier {
  @override
  void build() {}

  bool get _isAndroidStoreBuild => Platform.isAndroid && isStoreVersion();

  Future<Either<Failure, Unit>> startInAppPurchaseFlow({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) async {
    return ref.read(lanternServiceProvider).startInAppPurchaseFlow(
        planId: planId, onSuccess: onSuccess, onError: onError);
  }

  Future<Either<Failure, Unit>> acknowledgeInAppPurchase({
    required String purchaseToken,
    required String planId,
  }) async {
    return ref
        .read(lanternServiceProvider)
        .acknowledgeInAppPurchase(purchaseToken: purchaseToken, planId: planId);
  }

  Future<Either<Failure, String>> stripeSubscriptionLink(
      BillingType type, String planId, String email) async {
    return ref.read(lanternServiceProvider).stipeSubscriptionPaymentRedirect(
        type: type, planId: planId, email: email);
  }

  Future<Either<Failure, Map<String, dynamic>>> stripeSubscription(
      String planId, String email) async {
    return ref
        .read(lanternServiceProvider)
        .stipeSubscription(planId: planId, email: email);
  }

  Future<Either<Failure, String>> paymentRedirect({
    required String provider,
    required String planId,
    required String email,
  }) async {
    return ref
        .read(lanternServiceProvider)
        .paymentRedirect(provider: provider, planId: planId, email: email);
  }

  Future<Either<Failure, Unit>> startUpgradeFlow({
    required String planId,
    required String email,
    required BillingType billingType,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
    required String provider,
  }) async {
    if (_isAndroidStoreBuild) {
      // Google Play build uses IAP
      return startInAppPurchaseFlow(
        planId: planId,
        onSuccess: onSuccess,
        onError: onError,
      );
    }

    // Desktop and Android sideload use Stripe/Shepherd
    final redirectResult = await paymentRedirect(
      provider: provider,
      planId: planId,
      email: email,
    );

    return redirectResult.match(
      (failure) => left(failure),
      (url) {
        return right(unit);
      },
    );
  }
}
