import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

import '../core/services/app_purchase.dart';

/// LanternCoreService has all method that interact with lantern-core services
abstract class LanternCoreService {
  Future<void> init();

  Future<Either<Failure, Unit>> isVPNConnected();

  Future<Either<Failure, String>> startVPN();

  Future<Either<Failure, String>> stopVPN();

  Stream<LanternStatus> watchVPNStatus();

  Stream<List<String>> watchLogs(String path);

  ///Payments methods
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect(
      {required BillingType type,
      required String planId,
      required String email});

  Future<Either<Failure, String>> paymentRedirect({
    required String provider,
    required String planId,
    required String email,
  });

  // this is used for stripe subscription
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription(
      {required String planId, required String email});

  Future<Either<Failure, String>> stripeBillingPortal();

  // this is used for google and apple subscription
  Future<Either<Failure, Unit>> startInAppPurchaseFlow({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  });

  Future<Either<Failure, Unit>> acknowledgeInAppPurchase({
    required String purchaseToken,
    required String planId,
  });

  Future<Either<Failure, Unit>> showManageSubscriptions();

  Future<Either<Failure, PlansData>> plans();

  /// Spilt tunnel methods
  Future<Either<Failure, Unit>> addSplitTunnelItem(
      SplitTunnelFilterType type, String value);

  Future<Either<Failure, Unit>> removeSplitTunnelItem(
      SplitTunnelFilterType type, String value);

  Stream<List<AppData>> appsDataStream();

  ///OAuth methods
  Future<Either<Failure, String>> getOAuthLoginUrl(String provider);

  Future<Either<Failure, UserResponse>> oAuthLoginCallback(String token);

  Future<Either<Failure, Unit>> activationCode(
      {required String email, required String resellerCode});

  ///User management methods
  Future<Either<Failure, UserResponse>> login(
      {required String email, required String password});

  Future<Either<Failure, Unit>> signUp(
      {required String email, required String password});

  Future<Either<Failure, UserResponse>> getUserData();

  Future<Either<Failure, UserResponse>> fetchUserData();

  Future<Either<Failure, UserResponse>> logout(String email);

  //Forgot password
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email);

  Future<Either<Failure, Unit>> validateRecoveryCode(
      {required String email, required String code});

  Future<Either<Failure, Unit>> completeChangeEmail({
    required String email,
    required String code,
    required String newPassword,
  });

  //Delete account
  Future<Either<Failure, UserResponse>> deleteAccount(
      {required String email, required String password});
}
