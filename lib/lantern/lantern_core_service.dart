import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart' hide DeveloperMode;
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/referral_attach_response.dart';
import 'package:lantern/core/models/restore_subscription_response.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/features/report_issue/models/report_issue_attachment.dart';
import 'package:lantern/core/models/user.dart';

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
      final targetLen = (_maxBufferedLogLines * (1.0 - _logTrimFraction))
          .round();
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

  Future<Either<Failure, ServerLocation>> getSelectedServerLocation();

  Future<Either<Failure, String>> featureFlag();

  Future<Either<Failure, Unit>> setBlockAdsEnabled(bool enabled);

  Future<Either<Failure, bool>> isBlockAdsEnabled();

  Future<Either<Failure, Unit>> setPeerProxyEnabled(bool enabled);

  Future<Either<Failure, bool>> isPeerProxyEnabled();

  /// Persists the manually-configured router port forward used as the
  /// peer-share external port when set. Pass 0 to clear the override
  /// and revert to UPnP-discovered port behavior.
  Future<Either<Failure, Unit>> setPeerManualPort(int port);

  /// Returns the persisted manual port (0 if unset).
  Future<Either<Failure, int>> getPeerManualPort();

  /// Local opt-in for the broflake / Unbounded widget proxy ("Basic
  /// mode" in the Share My Connection UI). Actual run state also
  /// depends on server feature-flag and config availability.
  Future<Either<Failure, Unit>> setUnboundedEnabled(bool enabled);

  Future<Either<Failure, bool>> isUnboundedEnabled();

  /// Runs UPnP / IGD discovery on the local network and reports
  /// whether a usable gateway is reachable. Used by the Share My
  /// Connection toggle path to decide between SmC mode (residential
  /// proxy, needs UPnP or a manual port forward) and Unbounded mode
  /// (WebRTC, works anywhere) when no manual port is configured.
  /// Blocks for up to ~6 seconds on the multicast M-SEARCH wait;
  /// the FFI implementation runs in a background isolate.
  Future<Either<Failure, bool>> probeUPnP();

  Future<Either<Failure, bool>> isSmartRoutingEnabled();

  Future<Either<Failure, bool>> isTelemetryEnabled();

  Future<Either<Failure, bool>> isOAuthLogin();

  Future<Either<Failure, String>> getOAuthProvider();

  ///Payments methods
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect({
    required BillingType type,
    required String planId,
    required String email,
    required String idempotencyKey,
    String couponCode = '',
  });

  Future<Either<Failure, String>> paymentRedirect({
    required String provider,
    required String planId,
    required String email,
    required String idempotencyKey,
    String couponCode = '',
  });

  // this is used for stripe subscription
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription({
    required String planId,
    required String email,
    String couponCode = '',
  });

  Future<Either<Failure, String>> stripeBillingPortal();

  // this is used for google and apple subscription
  Future<Either<Failure, Unit>> startInAppPurchaseFlow({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
    String couponCode = '',
  });

  Future<Either<Failure, String>> acknowledgeInAppPurchase({
    required String purchaseToken,
    required String planId,
    String couponCode = '',
  });

  /// Restores a previously purchased subscription. Mobile-only.
  /// `purchaseToken` is the Google Play purchase token on Android, or the
  /// StoreKit receipt (server verification data) on iOS.
  Future<Either<Failure, RestoreSubscriptionResponse>> restoreInAppPurchase({
    required String purchaseToken,
  });

  Future<Either<Failure, Unit>> showManageSubscriptions();

  /// Spilt tunnel methods
  Future<Either<Failure, Unit>> addSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  );

  Future<Either<Failure, Unit>> removeSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  );

  Future<Either<Failure, Unit>> addAllItems(
    SplitTunnelFilterType type,
    List<String> value,
  );

  Future<Either<Failure, Unit>> removeAllItems(
    SplitTunnelFilterType type,
    List<String> value,
  );

  Future<Either<Failure, Unit>> setSplitTunnelingEnabled(bool enabled);

  Future<Either<Failure, bool>> isSplitTunnelingEnabled();

  Future<Either<Failure, Unit>> reportIssue(
    String email,
    String issueType,
    String description,
    String device,
    String model,
    String logFilePath,
    List<ReportIssueAttachment> attachments,
  );

  /// iOS only — returns paths to diagnostic log files.
  /// Throws [UnimplementedError] on other platforms.
  Future<Either<Failure, List<String>>> diagnosticLogFiles();

  Stream<List<AppData>> appsDataStream();
  Future<Uint8List?> loadInstalledAppIconBytes({
    required String appPath,
    required String iconPath,
  });

  ///OAuth methods
  Future<Either<Failure, String>> getOAuthLoginUrl(String provider);

  Future<Either<Failure, UserResponseModel>> oAuthLoginCallback(String token);

  /// Loads the account identity from a device-limit OAuth callback token so
  /// the follow-up device removal authenticates as that account, without
  /// logging the user in.
  Future<Either<Failure, Unit>> oAuthDeviceLimitCallback(String token);

  Future<Either<Failure, Unit>> activationCode({
    required String email,
    required String resellerCode,
  });

  ///User management methods
  Future<Either<Failure, UserResponseModel>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserResponseModel>> getUserData();

  Future<Either<Failure, UserResponseModel>> fetchUserData();

  Future<Either<Failure, DataCapUsageResponse>> getDataCapInfo();

  Future<Either<Failure, UserResponseModel>> logout(String email);

  //Change email
  /// Verifies the account password without mutating anything. Used to gate
  /// the change-email flow before the user enters a new email.
  Future<Either<Failure, String>> verifyPassword(
    String email,
    String password,
  );

  Future<Either<Failure, String>> startChangeEmail(
    String newEmail,
    String password,
  );

  Future<Either<Failure, String>> completeChangeEmail({
    required String newEmail,
    required String password,
    required String code,
  });

  //Forgot password
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email);

  Future<Either<Failure, Unit>> validateRecoveryCode({
    required String email,
    required String code,
  });

  Future<Either<Failure, Unit>> completeRecoveryByEmail({
    required String email,
    required String code,
    required String newPassword,
  });

  //Delete account
  Future<Either<Failure, UserResponseModel>> deleteAccount({
    required String email,
    required String password,
    bool isSSO = false,
  });

  //Device Remove
  Future<Either<Failure, String>> deviceRemove({required String deviceId});

  //Referral attachment
  Future<Either<Failure, String>> attachReferralCode(String code);

  //Referral attachment V2 — returns discounted plans, providers and discount
  Future<Either<Failure, ReferralAttachV2Response>> attachReferralCodeV2(
    String code,
  );

  /// Private server methods
  Future<Either<Failure, Unit>> digitalOceanPrivateServer();

  Future<Either<Failure, Unit>> googleCloudPrivateServer();

  Stream<PrivateServerStatus> watchPrivateServerStatus();

  Future<Either<Failure, Unit>> setUserInput({
    required PrivateServerInput methodType,
    required String input,
  });

  Future<Either<Failure, Unit>> validateSession();

  Future<Either<Failure, Unit>> startDeployment({
    required String location,
    required String serverName,
  });

  Future<Either<Failure, Unit>> addServerManually({
    required String ip,
    required String port,
    required String accessToken,
    required String serverName,
  });

  Future<Either<Failure, List<String>>> addServerBasedOnURLs({
    required String urls,
    required bool skipCertVerification,
  });

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
    String oldName,
    String newName,
  );

  Future<Either<Failure, List<String>>> getSplitTunnelItems(
    SplitTunnelFilterType type,
  );

  /// Developer-mode helpers exposing radiance settings/env controls.
  Future<Either<Failure, Unit>> patchSettings(Map<String, dynamic> updates);

  Future<Either<Failure, Map<String, dynamic>>> getSettings();

  Future<Either<Failure, Map<String, String>>> patchEnvVars(
    Map<String, String> updates,
  );

  Future<Either<Failure, Map<String, String>>> getEnvVars();

  Future<Either<Failure, Unit>> runURLTests();

  Future<Either<Failure, Unit>> sendConfigRequest();

  Future<Either<Failure, Unit>> clearTunnelCache();
}
