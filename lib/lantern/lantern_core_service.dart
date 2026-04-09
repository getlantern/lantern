import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart' hide DeveloperMode;
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

import '../core/services/app_purchase.dart';

const int _maxBufferedLogLines = 1000;
const double _logTrimFraction = 0.25;

/// Accumulates batches from [batches] into a growing buffer and re-emits the
/// full buffer on every update. When the buffer exceeds [_maxBufferedLogLines]
/// the oldest [_logTrimFraction] of lines are dropped in one go to reduce how
/// often the list is shifted.
Stream<List<String>> accumulateLogBatches(Stream<List<String>> batches) async* {
  final buffer = <String>[];
  await for (final batch in batches) {
    if (batch.isEmpty) continue;
    buffer.addAll(batch);
    if (buffer.length > _maxBufferedLogLines) {
      final targetLen = (_maxBufferedLogLines * (1.0 - _logTrimFraction)).round();
      buffer.removeRange(0, buffer.length - targetLen);
    }
    yield List<String>.unmodifiable(buffer);
  }
}

/// LanternCoreService has all method that interact with lantern-core services
abstract class LanternCoreService {
  Future<void> init();

  ///App Methods
  Future<Either<Failure, Unit>> updateLocal(String locale);

  Stream<AppEvent> watchAppEvents();

  Future<Either<Failure, Unit>> updateTelemetryEvents(bool consent);

  Future<Either<Failure, Unit>> setRoutingMode(bool mode);

  //VPN Methods

  Future<Either<Failure, bool>> isVPNConnected();

  Future<Either<Failure, String>> startVPN();

  Future<Either<Failure, String>> stopVPN();

  Future<Either<Failure, String>> connectToServer(String location, String tag);

  Future<bool> isTagAvailable(String tag);

  Future<bool> checkVpnConflict();

  Stream<LanternStatus> watchVPNStatus();

  Stream<List<String>> watchLogs(String path);

  Future<Either<Failure, Server>> getAutoServerLocation();

  Future<Either<Failure, String>> featureFlag();

  Future<Either<Failure, Unit>> setBlockAdsEnabled(bool enabled);

  Future<Either<Failure, bool>> isBlockAdsEnabled();

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

  Future<Either<Failure, String>> acknowledgeInAppPurchase({
    required String purchaseToken,
    required String planId,
  });

  Future<Either<Failure, Unit>> showManageSubscriptions();

  /// Spilt tunnel methods
  Future<Either<Failure, Unit>> addSplitTunnelItem(
      SplitTunnelFilterType type, String value);

  Future<Either<Failure, Unit>> removeSplitTunnelItem(
      SplitTunnelFilterType type, String value);

  Future<Either<Failure, Unit>> addAllItems(
      SplitTunnelFilterType type, List<String> value);

  Future<Either<Failure, Unit>> removeAllItems(
      SplitTunnelFilterType type, List<String> value);

  Future<Either<Failure, Unit>> setSplitTunnelingEnabled(bool enabled);

  Future<Either<Failure, bool>> isSplitTunnelingEnabled();

  Future<Either<Failure, Unit>> reportIssue(
    String email,
    String issueType,
    String description,
    String device,
    String model,
    String logFilePath,
  );

  /// iOS only — returns paths to diagnostic log files.
  /// Throws [UnimplementedError] on other platforms.
  Future<Either<Failure, List<String>>> diagnosticLogFiles();

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

  Future<Either<Failure, DataCapUsageResponse>> getDataCapInfo();

  Future<Either<Failure, UserResponse>> logout(String email);

  //Change email
  Future<Either<Failure, String>> startChangeEmail(
      String newEmail, String password);

  Future<Either<Failure, String>> completeChangeEmail({
    required String newEmail,
    required String password,
    required String code,
  });

  //Forgot password
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email);

  Future<Either<Failure, Unit>> validateRecoveryCode(
      {required String email, required String code});

  Future<Either<Failure, Unit>> completeRecoveryByEmail({
    required String email,
    required String code,
    required String newPassword,
  });

  //Delete account
  Future<Either<Failure, UserResponse>> deleteAccount(
      {required String email, required String password, bool isSSO = false});

  //Device Remove
  Future<Either<Failure, String>> deviceRemove({
    required String deviceId,
  });

  //Referral attachment
  Future<Either<Failure, String>> attachReferralCode(String code);

  /// Private server methods
  Future<Either<Failure, Unit>> digitalOceanPrivateServer();

  Future<Either<Failure, Unit>> googleCloudPrivateServer();

  Stream<PrivateServerStatus> watchPrivateServerStatus();

  Future<Either<Failure, Unit>> setUserInput(
      {required PrivateServerInput methodType, required String input});

  Future<Either<Failure, Unit>> validateSession();

  Future<Either<Failure, Unit>> startDeployment(
      {required String location, required String serverName});

  Future<Either<Failure, Unit>> addServerManually(
      {required String ip,
      required String port,
      required String accessToken,
      required String serverName});

  Future<Either<Failure, Unit>> addServerBasedOnURLs(
      {required String urls,
      required bool skipCertVerification,
      required String serverName});

  Future<Either<Failure, Unit>> cancelDeployment();

  Future<Either<Failure, String>> inviteToServerManagerInstance({
    required String ip,
    required String port,
    required String accessToken,
    required String inviteName,
  });

  Future<Either<Failure, String>> revokeServerManagerInstance({
    required String ip,
    required String port,
    required String accessToken,
    required String inviteName,
  });

  ///Custom/lantern server methods
  Future<Either<Failure, AvailableServers>> getLanternAvailableServers();

  ///MacOS System Extension methods
  Future<Either<Failure, String>> triggerSystemExtension();

  Future<Either<Failure, Unit>> openSystemExtension();

  Future<Either<Failure, Unit>> isSystemExtensionInstalled();

  Stream<MacOSExtensionState> watchSystemExtensionStatus();

  /// Plans (remote)
  Future<Either<Failure, PlansData>> plans();

  Future<Either<Failure, Unit>> deletePrivateServerByName(String serverName);

  Future<Either<Failure, Unit>> updatePrivateServerName(
      String oldName, String newName);

  Future<Either<Failure, List<String>>> getSplitTunnelItems(
    SplitTunnelFilterType type,
  );
}
