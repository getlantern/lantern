import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/plan_data.dart';

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
      {required StipeSubscriptionType type, required String planId});

  /// this is used for stripe subscription
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription(
      {required String planId});

  /// this is used for google and apple subscription
  Future<Either<Failure, Unit>> startSubscriptionFlow({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  });

  Future<Either<Failure, PlansData>> plans();

  Future<Either<Failure, Unit>> cancelSubscription();

  Future<Either<Failure, Unit>> makeOneTimePayment({required String planID});
  Stream<List<AppData>> appsDataStream();

  Stream<List<String>> logsStream();

  // Spilt tunnel methods
  Future<Either<Failure, Unit>> addSplitTunnelItem(
      SplitTunnelFilterType type, String value);

  Future<Either<Failure, Unit>> removeSplitTunnelItem(
      SplitTunnelFilterType type, String value);
}
