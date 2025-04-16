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

  Future<Either<Failure, Unit>> subscribeToPlan({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) async {
    return ref.read(lanternServiceProvider).subscribeToPlan(
        planId: planId, onSuccess: onSuccess, onError: onError);
  }

  Future<Either<Failure, String>> subscribeLink() async {
    return ref.read(lanternServiceProvider).subscriptionLink();
  }
}
