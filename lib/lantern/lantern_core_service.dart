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

  Stream<LanternStatus> watchVPNStatus();

  //Payments methods
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect(
      {required StipeSubscriptionType type,required String planId});


  Future<Either<Failure, Unit>> subscribeToPlan({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  });

  Future<Either<Failure, Unit>> cancelSubscription();

  Future<Either<Failure, Unit>> makeOneTimePayment({required String planID});
}
