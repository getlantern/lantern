// lantern_service.dart
import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/entity/app_data.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

import '../core/common/common.dart';
import '../core/models/available_servers.dart';

/// LanternService is wrapper around native and ffi services
/// all communication happens here.
class LanternService implements LanternCoreService {
  final LanternFFIService _ffiService;
  final LanternPlatformService _platformService;

  LanternService({
    required LanternFFIService ffiService,
    required LanternPlatformService platformService,
    required AppPurchase appPurchase,
  })  : _platformService = platformService,
        _ffiService = ffiService;

  T _choose<T>(
    T Function(LanternFFIService ffi) ffi,
    T Function(LanternPlatformService platform) platform,
  ) {
    if (PlatformUtils.isFFISupported) return ffi(_ffiService);
    return platform(_platformService);
  }

  @override
  Future<Either<Failure, String>> startVPN() =>
      _choose((s) => s.startVPN(), (s) => s.startVPN());

  @override
  Future<Either<Failure, String>> stopVPN() =>
      _choose((s) => s.stopVPN(), (s) => s.stopVPN());

  @override
  Stream<List<AppData>> appsDataStream() =>
      _choose((s) => s.appsDataStream(), (s) => s.appsDataStream());

  @override
  Future<Either<Failure, Unit>> updateLocal(String locale) =>
      _choose((s) => s.updateLocal(locale), (s) => s.updateLocal(locale));

  @override
  Stream<AppEvent> watchAppEvents() =>
      _choose((s) => s.watchAppEvents(), (s) => s.watchAppEvents());

  @override
  Future<Either<Failure, Unit>> updateTelemetryEvents(bool consent) => _choose(
      (s) => s.updateTelemetryEvents(consent),
      (s) => s.updateTelemetryEvents(consent));

  @override
  Stream<LanternStatus> watchVPNStatus() =>
      _choose((s) => s.watchVPNStatus(), (s) => s.watchVPNStatus());

  @override
  Stream<List<String>> watchLogs(String path) =>
      _choose((s) => s.watchLogs(path), (s) => s.watchLogs(path));

  @override
  Future<Either<Failure, bool>> isVPNConnected() =>
      _choose((s) => s.isVPNConnected(), (s) => s.isVPNConnected());

  @override
  Future<Either<Failure, Unit>> startInAppPurchaseFlow({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) =>
      _choose(
        (_) => Future.value(left(Failure(
          error: 'Not supported',
          localizedErrorMessage: 'In-app purchase flow is not supported here',
        ))),
        (s) => s.startInAppPurchaseFlow(
          planId: planId,
          onSuccess: onSuccess,
          onError: onError,
        ),
      );

  @override
  Future<Either<Failure, DataCapInfo>> getDataCapInfo() =>
      _choose((s) => s.getDataCapInfo(), (s) => s.getDataCapInfo());

  @override
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect({
    required BillingType type,
    required String planId,
    required String email,
  }) =>
      _choose(
        (s) => s.stipeSubscriptionPaymentRedirect(
            type: type, planId: planId, email: email),
        (s) => s.stipeSubscriptionPaymentRedirect(
            type: type, planId: planId, email: email),
      );

  @override
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription({
    required String planId,
    required String email,
  }) =>
      _choose(
        (_) => Future.value(left(Failure(
          error: 'Not supported',
          localizedErrorMessage: 'This flow is not supported on this platform',
        ))),
        (s) => s.stipeSubscription(planId: planId, email: email),
      );

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
          SplitTunnelFilterType type, String value) =>
      _choose((s) => s.addSplitTunnelItem(type, value),
          (s) => s.addSplitTunnelItem(type, value));

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
          SplitTunnelFilterType type, String value) =>
      _choose((s) => s.removeSplitTunnelItem(type, value),
          (s) => s.removeSplitTunnelItem(type, value));

  @override
  Future<Either<Failure, Unit>> setSplitTunnelingEnabled(bool enabled) =>
      _choose((s) => s.setSplitTunnelingEnabled(enabled),
          (s) => s.setSplitTunnelingEnabled(enabled));

  @override
  Future<Either<Failure, bool>> isSplitTunnelingEnabled() => _choose(
      (s) => s.isSplitTunnelingEnabled(), (s) => s.isSplitTunnelingEnabled());

  @override
  Future<Either<Failure, Unit>> reportIssue(
    String email,
    String issueType,
    String description,
    String device,
    String model,
    String logFilePath,
  ) =>
      _choose(
        (s) => s.reportIssue(
            email, issueType, description, device, model, logFilePath),
        (s) => s.reportIssue(
            email, issueType, description, device, model, logFilePath),
      );

  @override
  Future<Either<Failure, PlansData>> plans() =>
      _choose((s) => s.plans(), (s) => s.plans());

  @override
  Future<Either<Failure, String>> getOAuthLoginUrl(String provider) => _choose(
      (s) => s.getOAuthLoginUrl(provider), (s) => s.getOAuthLoginUrl(provider));

  @override
  Future<Either<Failure, UserResponse>> oAuthLoginCallback(String token) =>
      _choose((s) => s.oAuthLoginCallback(token),
          (s) => s.oAuthLoginCallback(token));

  @override
  Future<Either<Failure, UserResponse>> getUserData() =>
      _choose((s) => s.getUserData(), (s) => s.getUserData());

  @override
  Future<Either<Failure, String>> stripeBillingPortal() =>
      _choose((s) => s.stripeBillingPortal(), (s) => s.stripeBillingPortal());

  @override
  Future<Either<Failure, Unit>> showManageSubscriptions() => _choose(
      (s) => s.showManageSubscriptions(), (s) => s.showManageSubscriptions());

  @override
  Future<Either<Failure, UserResponse>> fetchUserData() =>
      _choose((s) => s.fetchUserData(), (s) => s.fetchUserData());

  @override
  Future<Either<Failure, Unit>> acknowledgeInAppPurchase({
    required String purchaseToken,
    required String planId,
  }) =>
      _choose(
        (s) => s.acknowledgeInAppPurchase(
            purchaseToken: purchaseToken, planId: planId),
        (s) => s.acknowledgeInAppPurchase(
            purchaseToken: purchaseToken, planId: planId),
      );

  @override
  Future<Either<Failure, UserResponse>> logout(String email) =>
      _choose((s) => s.logout(email), (s) => s.logout(email));

  @override
  Future<Either<Failure, String>> paymentRedirect({
    required String provider,
    required String planId,
    required String email,
  }) =>
      _choose(
        (s) =>
            s.paymentRedirect(provider: provider, planId: planId, email: email),
        (s) =>
            s.paymentRedirect(provider: provider, planId: planId, email: email),
      );

  @override
  Future<Either<Failure, UserResponse>> login({
    required String email,
    required String password,
  }) =>
      _choose((s) => s.login(email: email, password: password),
          (s) => s.login(email: email, password: password));

  @override
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email) => _choose(
      (s) => s.startRecoveryByEmail(email),
      (s) => s.startRecoveryByEmail(email));

  @override
  Future<Either<Failure, Unit>> validateRecoveryCode({
    required String email,
    required String code,
  }) =>
      _choose((s) => s.validateRecoveryCode(email: email, code: code),
          (s) => s.validateRecoveryCode(email: email, code: code));

  @override
  Future<Either<Failure, Unit>> completeRecoveryByEmail({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _choose(
        (s) => s.completeRecoveryByEmail(
            email: email, code: code, newPassword: newPassword),
        (s) => s.completeRecoveryByEmail(
            email: email, code: code, newPassword: newPassword),
      );

  @override
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  }) =>
      _choose((s) => s.signUp(email: email, password: password),
          (s) => s.signUp(email: email, password: password));

  @override
  Future<Either<Failure, UserResponse>> deleteAccount({
    required String email,
    required String password,
  }) =>
      _choose((s) => s.deleteAccount(email: email, password: password),
          (s) => s.deleteAccount(email: email, password: password));

  @override
  Future<Either<Failure, Unit>> activationCode({
    required String email,
    required String resellerCode,
  }) =>
      _choose((s) => s.activationCode(email: email, resellerCode: resellerCode),
          (s) => s.activationCode(email: email, resellerCode: resellerCode));

  @override
  Future<Either<Failure, Unit>> digitalOceanPrivateServer() => _choose(
      (s) => s.digitalOceanPrivateServer(),
      (s) => s.digitalOceanPrivateServer());

  @override
  Future<Either<Failure, Unit>> googleCloudPrivateServer() => _choose(
      (s) => s.googleCloudPrivateServer(), (s) => s.googleCloudPrivateServer());

  @override
  Stream<PrivateServerStatus> watchPrivateServerStatus() => _choose(
      (s) => s.watchPrivateServerStatus(), (s) => s.watchPrivateServerStatus());

  @override
  Future<Either<Failure, Unit>> validateSession() =>
      _choose((s) => s.validateSession(), (s) => s.validateSession());

  @override
  Future<Either<Failure, Unit>> setUserInput({
    required PrivateServerInput methodType,
    required String input,
  }) =>
      _choose((s) => s.setUserInput(methodType: methodType, input: input),
          (s) => s.setUserInput(methodType: methodType, input: input));

  @override
  Future<Either<Failure, Unit>> cancelDeployment() =>
      _choose((s) => s.cancelDeployment(), (s) => s.cancelDeployment());

  @override
  Future<Either<Failure, Unit>> startDeployment({
    required String location,
    required String serverName,
  }) =>
      _choose(
          (s) => s.startDeployment(location: location, serverName: serverName),
          (s) => s.startDeployment(location: location, serverName: serverName));

  @override
  Future<Either<Failure, Unit>> setCert({required String fingerprint}) =>
      _choose((s) => s.setCert(fingerprint: fingerprint),
          (s) => s.setCert(fingerprint: fingerprint));

  @override
  Future<Either<Failure, Unit>> addServerManually({
    required String ip,
    required String port,
    required String accessToken,
    required String serverName,
  }) =>
      _choose(
        (s) => s.addServerManually(
            ip: ip,
            port: port,
            accessToken: accessToken,
            serverName: serverName),
        (s) => s.addServerManually(
            ip: ip,
            port: port,
            accessToken: accessToken,
            serverName: serverName),
      );

  @override
  Future<Either<Failure, String>> connectToServer(
          String location, String tag) =>
      _choose((s) => s.connectToServer(location, tag),
          (s) => s.connectToServer(location, tag));

  @override
  Future<Either<Failure, String>> inviteToServerManagerInstance({
    required String ip,
    required String port,
    required String accessToken,
    required String inviteName,
  }) =>
      _choose(
        (s) => s.inviteToServerManagerInstance(
            ip: ip,
            port: port,
            accessToken: accessToken,
            inviteName: inviteName),
        (s) => s.inviteToServerManagerInstance(
            ip: ip,
            port: port,
            accessToken: accessToken,
            inviteName: inviteName),
      );

  @override
  Future<Either<Failure, String>> revokeServerManagerInstance({
    required String ip,
    required String port,
    required String accessToken,
    required String inviteName,
  }) =>
      _choose(
        (s) => s.revokeServerManagerInstance(
            ip: ip,
            port: port,
            accessToken: accessToken,
            inviteName: inviteName),
        (s) => s.revokeServerManagerInstance(
            ip: ip,
            port: port,
            accessToken: accessToken,
            inviteName: inviteName),
      );

  @override
  Future<Either<Failure, String>> featureFlag() =>
      _choose((s) => s.featureFlag(), (s) => s.featureFlag());

  @override
  Future<Either<Failure, AvailableServers>> getLanternAvailableServers() =>
      _choose((s) => s.getLanternAvailableServers(),
          (s) => s.getLanternAvailableServers());

  @override
  Future<Either<Failure, String>> deviceRemove({required String deviceId}) =>
      _choose((s) => s.deviceRemove(deviceId: deviceId),
          (s) => s.deviceRemove(deviceId: deviceId));

  @override
  Future<Either<Failure, String>> completeChangeEmail({
    required String newEmail,
    required String password,
    required String code,
  }) =>
      _choose(
        (s) => s.completeChangeEmail(
            newEmail: newEmail, password: password, code: code),
        (s) => s.completeChangeEmail(
            newEmail: newEmail, password: password, code: code),
      );

  @override
  Future<Either<Failure, String>> startChangeEmail(
          String newEmail, String password) =>
      _choose((s) => s.startChangeEmail(newEmail, password),
          (s) => s.startChangeEmail(newEmail, password));

  @override
  Future<Either<Failure, Server>> getAutoServerLocation() => _choose(
      (s) => s.getAutoServerLocation(), (s) => s.getAutoServerLocation());

  @override
  Future<Either<Failure, String>> triggerSystemExtension() => _choose(
      (s) => s.triggerSystemExtension(), (s) => s.triggerSystemExtension());

  @override
  Stream<MacOSExtensionState> watchSystemExtensionStatus() => _choose(
      (s) => s.watchSystemExtensionStatus(),
      (s) => s.watchSystemExtensionStatus());

  @override
  Future<Either<Failure, Unit>> openSystemExtension() =>
      _choose((s) => s.openSystemExtension(), (s) => s.openSystemExtension());

  @override
  Future<Either<Failure, Unit>> isSystemExtensionInstalled() => _choose(
      (s) => s.isSystemExtensionInstalled(),
      (s) => s.isSystemExtensionInstalled());

  @override
  Future<Either<Failure, Unit>> addAllItems(
          SplitTunnelFilterType type, List<String> value) =>
      _choose(
          (s) => s.addAllItems(type, value), (s) => s.addAllItems(type, value));

  @override
  Future<Either<Failure, Unit>> removeAllItems(
          SplitTunnelFilterType type, List<String> value) =>
      _choose((s) => s.removeAllItems(type, value),
          (s) => s.removeAllItems(type, value));

  @override
  Future<Either<Failure, bool>> isBlockAdsEnabled() =>
      _choose((s) => s.isBlockAdsEnabled(), (s) => s.isBlockAdsEnabled());

  @override
  Future<Either<Failure, Unit>> setBlockAdsEnabled(bool enabled) => _choose(
      (s) => s.setBlockAdsEnabled(enabled),
      (s) => s.setBlockAdsEnabled(enabled));

  @override
  Future<Either<Failure, String>> attachReferralCode(String code) => _choose(
      (s) => s.attachReferralCode(code), (s) => s.attachReferralCode(code));
}
