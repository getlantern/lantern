import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';

import '../core/services/app_purchase.dart';

/// LanternCoreService has all method that interact with lantern-core services
abstract class LanternCoreService {
  Future<void> init();

  Future<Either<Failure, Unit>> isVPNConnected();

  Future<Either<Failure, String>> startVPN();

  Future<Either<Failure, String>> stopVPN();

  Future<Either<Failure, String>> subscriptionLink();

  Stream<LanternStatus> watchVPNStatus();



  // Payments
  Future<Either<Failure, Unit>> subscribeToPlan({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  });

  Future<Either<Failure, Unit>> cancelSubscription();

  Future<Either<Failure, Unit>> makeOneTimePayment({required String planID});
}
