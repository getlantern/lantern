import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/restore_subscription_response.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payment_notifier.g.dart';

/// Notifier to manage the state of payment sessions
@Riverpod(keepAlive: true)
class PaymentSessionNotifier extends _$PaymentSessionNotifier {
  @override
  bool build() => false;

  void markRedirectInitiated() => state = true;

  void clearRedirect() => state = false;
}

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
    if (!AppBuildInfo.enableStorePayments) {
      return left(Failure.featureDisabled('In-app purchase'));
    }
    return ref
        .read(lanternServiceProvider)
        .startInAppPurchaseFlow(
          planId: planId,
          onSuccess: onSuccess,
          onError: onError,
        );
  }

  Future<Either<Failure, String>> acknowledgeInAppPurchase({
    required String purchaseToken,
    required String planId,
  }) async {
    if (!AppBuildInfo.enableStorePayments) {
      return left(Failure.featureDisabled('In-app purchase'));
    }
    return ref
        .read(lanternServiceProvider)
        .acknowledgeInAppPurchase(purchaseToken: purchaseToken, planId: planId);
  }

  Future<Either<Failure, RestoreSubscriptionResponse>> restoreInAppPurchase({
    required String purchaseToken,
  }) async {
    if (!AppBuildInfo.enableStorePayments) {
      return left(Failure.featureDisabled('Restore purchase'));
    }
    return ref
        .read(lanternServiceProvider)
        .restoreInAppPurchase(purchaseToken: purchaseToken);
  }

  Future<Either<Failure, String>> stripeSubscriptionLink(
    BillingType type,
    String planId,
    String email,
  ) async {
    if (!AppBuildInfo.enablePayments) {
      return left(Failure.featureDisabled('Payment'));
    }
    final idempotencyKey = generatePaymentRedirectIdempotencyKey();
    return ref
        .read(lanternServiceProvider)
        .stipeSubscriptionPaymentRedirect(
          type: type,
          planId: planId,
          email: email,
          idempotencyKey: idempotencyKey,
        );
  }

  Future<Either<Failure, Map<String, dynamic>>> stripeSubscription(
    String planId,
    String email,
  ) async {
    if (!AppBuildInfo.enablePayments) {
      return left(Failure.featureDisabled('Payment'));
    }
    return ref
        .read(lanternServiceProvider)
        .stipeSubscription(planId: planId, email: email);
  }

  Future<Either<Failure, String>> paymentRedirect({
    required String provider,
    required String planId,
    required String email,
  }) async {
    if (!AppBuildInfo.enablePayments) {
      return left(Failure.featureDisabled('Payment'));
    }
    final idempotencyKey = generatePaymentRedirectIdempotencyKey();
    return ref
        .read(lanternServiceProvider)
        .paymentRedirect(
          provider: provider,
          planId: planId,
          email: email,
          idempotencyKey: idempotencyKey,
        );
  }

  Future<Either<Failure, String?>> startUpgradeFlow({
    required String planId,
    required String email,
    required BillingType billingType,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
    required String provider,
  }) async {
    if (!AppBuildInfo.enablePayments) {
      return left(Failure.featureDisabled('Payment'));
    }
    if (_isAndroidStoreBuild) {
      // Google Play build uses IAP
      final result = await startInAppPurchaseFlow(
        planId: planId,
        onSuccess: onSuccess,
        onError: onError,
      );

      return result.match((failure) => left(failure), (_) => right(null));
    }

    // Desktop and Android sideload use Stripe/Shepherd
    final redirectResult = await paymentRedirect(
      provider: provider,
      planId: planId,
      email: email,
    );

    return redirectResult.match(
      (failure) => left(failure),
      (url) => right(url),
    );
  }
}
