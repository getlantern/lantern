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
}
