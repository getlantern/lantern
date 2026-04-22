import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/app_event.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/lantern_platform_service.dart';
import 'package:lantern/core/models/user.dart';

import '../core/common/common.dart' hide DeveloperMode;
import '../core/models/available_servers.dart';

///LanternService is wrapper around native and ffi services
/// all communication happens here
class LanternService implements LanternCoreService {
  final LanternFFIService _ffiService;

  final LanternPlatformService _platformService;

  LanternService({
    required LanternFFIService ffiService,
    required LanternPlatformService platformService,
    required AppPurchase appPurchase,
  }) : _platformService = platformService,
       _ffiService = ffiService;

  @override
  Future<void> init() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.init();
    }
    return _platformService.init();
  }

  @override
  Future<Either<Failure, String>> startVPN() async {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.startVPN();
    }
    return _platformService.startVPN();
  }

  @override
  Future<bool> isTagAvailable(String tag) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.isTagAvailable(tag);
    }
    return _platformService.isTagAvailable(tag);
  }

  @override
  Future<Either<Failure, String>> stopVPN() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.stopVPN();
    }
    return _platformService.stopVPN();
  }

  @override
  Stream<List<AppData>> appsDataStream() async* {
    if (PlatformUtils.isFFISupported) {
      yield* _ffiService.appsDataStream();
    } else {
      yield* _platformService.appsDataStream();
    }
  }

  @override
  Future<Uint8List?> loadInstalledAppIconBytes({
    required String appPath,
    required String iconPath,
  }) async {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.loadInstalledAppIconBytes(
        appPath: appPath,
        iconPath: iconPath,
      );
    }
    return _platformService.loadInstalledAppIconBytes(
      appPath: appPath,
      iconPath: iconPath,
    );
  }

  @override
  Future<Either<Failure, Unit>> updateLocal(String locale) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.updateLocal(locale);
    }
    return _platformService.updateLocal(locale);
  }

  @override
  Stream<AppEvent> watchAppEvents() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.watchAppEvents();
    }
    return _platformService.watchAppEvents();
  }

  @override
  Future<Either<Failure, Unit>> updateTelemetryEvents(bool consent) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.updateTelemetryEvents(consent);
    }
    return _platformService.updateTelemetryEvents(consent);
  }

  @override
  Future<Either<Failure, Unit>> setRoutingMode(bool mode) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.setRoutingMode(mode);
    }
    return _platformService.setRoutingMode(mode);
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.watchVPNStatus();
    }
    return _platformService.watchVPNStatus();
  }

  @override
  Stream<List<String>> watchLogs(String path) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.watchLogs(path);
    }
    return _platformService.watchLogs(path);
  }

  @override
  Future<Either<Failure, bool>> isVPNConnected() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.isVPNConnected();
    }
    return _platformService.isVPNConnected();
  }

  @override
  Future<Either<Failure, Unit>> startInAppPurchaseFlow({
    required String planId,
    required PaymentSuccessCallback onSuccess,
    required PaymentErrorCallback onError,
  }) {
    if (PlatformUtils.isFFISupported) {
      throw UnimplementedError();
    }
    return _platformService.startInAppPurchaseFlow(
      planId: planId,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  @override
  Future<Either<Failure, DataCapUsageResponse>> getDataCapInfo() async {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.getDataCapInfo();
    }
    return _platformService.getDataCapInfo();
  }

  @override
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect({
    required BillingType type,
    required String planId,
    required String email,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.stipeSubscriptionPaymentRedirect(
        type: type,
        planId: planId,
        email: email,
      );
    }
    return _platformService.stipeSubscriptionPaymentRedirect(
      type: type,
      planId: planId,
      email: email,
    );
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription({
    required String planId,
    required String email,
  }) {
    if (PlatformUtils.isFFISupported) {
      throw UnimplementedError();
    }
    return _platformService.stipeSubscription(planId: planId, email: email);
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  ) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.addSplitTunnelItem(type, value);
    }
    return _platformService.addSplitTunnelItem(type, value);
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
    SplitTunnelFilterType type,
    String value,
  ) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.removeSplitTunnelItem(type, value);
    }
    return _platformService.removeSplitTunnelItem(type, value);
  }

  @override
  Future<Either<Failure, Unit>> setSplitTunnelingEnabled(bool enabled) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.setSplitTunnelingEnabled(enabled);
    }
    return _platformService.setSplitTunnelingEnabled(enabled);
  }

  @override
  Future<Either<Failure, bool>> isSplitTunnelingEnabled() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.isSplitTunnelingEnabled();
    }
    return _platformService.isSplitTunnelingEnabled();
  }

  @override
  Future<Either<Failure, Unit>> reportIssue(
    String email,
    String issueType,
    String description,
    String device,
    String model,
    String logFilePath,
  ) async {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.reportIssue(
        email,
        issueType,
        description,
        device,
        model,
        logFilePath,
      );
    }
    return _platformService.reportIssue(
      email,
      issueType,
      description,
      device,
      model,
      logFilePath,
    );
  }

  @override
  Future<Either<Failure, PlansData>> plans() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.plans();
    }
    return _platformService.plans();
  }

  @override
  Future<Either<Failure, String>> getOAuthLoginUrl(String provider) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.getOAuthLoginUrl(provider);
    }
    return _platformService.getOAuthLoginUrl(provider);
  }

  @override
  Future<Either<Failure, UserResponseModel>> oAuthLoginCallback(String token) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.oAuthLoginCallback(token);
    }
    return _platformService.oAuthLoginCallback(token);
  }

  @override
  Future<Either<Failure, UserResponseModel>> getUserData() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.getUserData();
    }
    return _platformService.getUserData();
  }

  @override
  Future<Either<Failure, String>> stripeBillingPortal() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.stripeBillingPortal();
    }
    return _platformService.stripeBillingPortal();
  }

  @override
  Future<Either<Failure, Unit>> showManageSubscriptions() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.showManageSubscriptions();
    }
    return _platformService.showManageSubscriptions();
  }

  @override
  Future<Either<Failure, UserResponseModel>> fetchUserData() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.fetchUserData();
    }
    return _platformService.fetchUserData();
  }

  @override
  Future<Either<Failure, String>> acknowledgeInAppPurchase({
    required String purchaseToken,
    required String planId,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.acknowledgeInAppPurchase(
        purchaseToken: purchaseToken,
        planId: planId,
      );
    }
    return _platformService.acknowledgeInAppPurchase(
      purchaseToken: purchaseToken,
      planId: planId,
    );
  }

  @override
  Future<Either<Failure, UserResponseModel>> logout(String email) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.logout(email);
    }
    return _platformService.logout(email);
  }

  @override
  Future<Either<Failure, String>> paymentRedirect({
    required String provider,
    required String planId,
    required String email,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.paymentRedirect(
        provider: provider,
        planId: planId,
        email: email,
      );
    }
    return _platformService.paymentRedirect(
      provider: provider,
      planId: planId,
      email: email,
    );
  }

  @override
  Future<Either<Failure, UserResponseModel>> login({
    required String email,
    required String password,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.login(email: email, password: password);
    }
    return _platformService.login(email: email, password: password);
  }

  @override
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.startRecoveryByEmail(email);
    }
    return _platformService.startRecoveryByEmail(email);
  }

  @override
  Future<Either<Failure, Unit>> validateRecoveryCode({
    required String email,
    required String code,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.validateRecoveryCode(email: email, code: code);
    }
    return _platformService.validateRecoveryCode(email: email, code: code);
  }

  @override
  Future<Either<Failure, Unit>> completeRecoveryByEmail({
    required String email,
    required String code,
    required String newPassword,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.completeRecoveryByEmail(
        email: email,
        code: code,
        newPassword: newPassword,
      );
    }
    return _platformService.completeRecoveryByEmail(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }

  @override
  Future<Either<Failure, Unit>> signUp({
    required String email,
    required String password,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.signUp(email: email, password: password);
    }
    return _platformService.signUp(email: email, password: password);
  }

  @override
  Future<Either<Failure, UserResponseModel>> deleteAccount({
    required String email,
    required String password,
    bool isSSO = false,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.deleteAccount(
        email: email,
        password: password,
        isSSO: isSSO,
      );
    }
    return _platformService.deleteAccount(
      email: email,
      password: password,
      isSSO: isSSO,
    );
  }

  @override
  Future<Either<Failure, Unit>> activationCode({
    required String email,
    required String resellerCode,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.activationCode(
        email: email,
        resellerCode: resellerCode,
      );
    }
    return _platformService.activationCode(
      email: email,
      resellerCode: resellerCode,
    );
  }

  @override
  Future<Either<Failure, Unit>> digitalOceanPrivateServer() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.digitalOceanPrivateServer();
    }
    return _platformService.digitalOceanPrivateServer();
  }

  @override
  Future<Either<Failure, Unit>> googleCloudPrivateServer() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.googleCloudPrivateServer();
    }
    return _platformService.googleCloudPrivateServer();
  }

  @override
  Stream<PrivateServerStatus> watchPrivateServerStatus() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.watchPrivateServerStatus();
    }
    return _platformService.watchPrivateServerStatus();
  }

  @override
  Future<Either<Failure, Unit>> validateSession() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.validateSession();
    }
    return _platformService.validateSession();
  }

  @override
  Future<Either<Failure, Unit>> setUserInput({
    required PrivateServerInput methodType,
    required String input,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.setUserInput(methodType: methodType, input: input);
    }
    return _platformService.setUserInput(methodType: methodType, input: input);
  }

  @override
  Future<Either<Failure, Unit>> cancelDeployment() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.cancelDeployment();
    }
    return _platformService.cancelDeployment();
  }

  @override
  Future<Either<Failure, Unit>> startDeployment({
    required String location,
    required String serverName,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.startDeployment(
        location: location,
        serverName: serverName,
      );
    }
    return _platformService.startDeployment(
      location: location,
      serverName: serverName,
    );
  }

  @override
  Future<Either<Failure, Unit>> addServerManually({
    required String ip,
    required String port,
    required String accessToken,
    required String serverName,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.addServerManually(
        ip: ip,
        port: port,
        accessToken: accessToken,
        serverName: serverName,
      );
    }
    return _platformService.addServerManually(
      ip: ip,
      port: port,
      accessToken: accessToken,
      serverName: serverName,
    );
  }

  @override
  Future<Either<Failure, List<String>>> addServerBasedOnURLs({
    required String urls,
    required bool skipCertVerification,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.addServerBasedOnURLs(
        urls: urls,
        skipCertVerification: skipCertVerification,
      );
    }
    return _platformService.addServerBasedOnURLs(
      urls: urls,
      skipCertVerification: skipCertVerification,
    );
  }

  /// connectToServer is used to connect to a server
  /// this will work with lantern customer and private server
  /// requires location and tag
  @override
  Future<Either<Failure, String>> connectToServer(String location, String tag) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.connectToServer(location, tag);
    }
    return _platformService.connectToServer(location, tag);
  }

  @override
  Future<Either<Failure, String>> inviteToServerManagerInstance({
    required String ip,
    required String port,
    required String accessToken,
    required String inviteName,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.inviteToServerManagerInstance(
        ip: ip,
        port: port,
        accessToken: accessToken,
        inviteName: inviteName,
      );
    }
    return _platformService.inviteToServerManagerInstance(
      ip: ip,
      port: port,
      accessToken: accessToken,
      inviteName: inviteName,
    );
  }

  @override
  Future<Either<Failure, String>> revokeServerManagerInstance({
    required String ip,
    required String port,
    required String accessToken,
    required String inviteName,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.revokeServerManagerInstance(
        ip: ip,
        port: port,
        accessToken: accessToken,
        inviteName: inviteName,
      );
    }
    return _platformService.revokeServerManagerInstance(
      ip: ip,
      port: port,
      accessToken: accessToken,
      inviteName: inviteName,
    );
  }

  @override
  Future<Either<Failure, String>> featureFlag() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.featureFlag();
    }
    return _platformService.featureFlag();
  }

  @override
  Future<Either<Failure, AvailableServers>> getLanternAvailableServers() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.getLanternAvailableServers();
    }
    return _platformService.getLanternAvailableServers();
  }

  @override
  Future<Either<Failure, String>> deviceRemove({required String deviceId}) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.deviceRemove(deviceId: deviceId);
    }
    return _platformService.deviceRemove(deviceId: deviceId);
  }

  @override
  Future<Either<Failure, String>> completeChangeEmail({
    required String newEmail,
    required String password,
    required String code,
  }) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.completeChangeEmail(
        newEmail: newEmail,
        password: password,
        code: code,
      );
    }
    return _platformService.completeChangeEmail(
      newEmail: newEmail,
      password: password,
      code: code,
    );
  }

  @override
  Future<Either<Failure, String>> startChangeEmail(
    String newEmail,
    String password,
  ) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.startChangeEmail(newEmail, password);
    }
    return _platformService.startChangeEmail(newEmail, password);
  }

  @override
  Future<Either<Failure, Server>> getAutoServerLocation() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.getAutoServerLocation();
    }
    return _platformService.getAutoServerLocation();
  }

  @override
  Future<Either<Failure, ServerLocation>> getSelectedServerLocation() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.getSelectedServerLocation();
    }
    return _platformService.getSelectedServerLocation();
  }

  @override
  Future<Either<Failure, String>> triggerSystemExtension() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.triggerSystemExtension();
    }
    return _platformService.triggerSystemExtension();
  }

  @override
  Stream<MacOSExtensionState> watchSystemExtensionStatus() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.watchSystemExtensionStatus();
    }
    return _platformService.watchSystemExtensionStatus();
  }

  @override
  Future<Either<Failure, Unit>> openSystemExtension() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.openSystemExtension();
    }
    return _platformService.openSystemExtension();
  }

  @override
  Future<Either<Failure, Unit>> isSystemExtensionInstalled() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.isSystemExtensionInstalled();
    }
    return _platformService.isSystemExtensionInstalled();
  }

  @override
  Future<Either<Failure, Unit>> addAllItems(
    SplitTunnelFilterType type,
    List<String> value,
  ) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.addAllItems(type, value);
    }
    return _platformService.addAllItems(type, value);
  }

  @override
  Future<Either<Failure, Unit>> removeAllItems(
    SplitTunnelFilterType type,
    List<String> value,
  ) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.removeAllItems(type, value);
    }
    return _platformService.removeAllItems(type, value);
  }

  @override
  Future<Either<Failure, bool>> isBlockAdsEnabled() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.isBlockAdsEnabled();
    }
    return _platformService.isBlockAdsEnabled();
  }

  @override
  Future<Either<Failure, Unit>> setBlockAdsEnabled(bool enabled) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.setBlockAdsEnabled(enabled);
    }
    return _platformService.setBlockAdsEnabled(enabled);
  }

  @override
  Future<Either<Failure, bool>> isSmartRoutingEnabled() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.isSmartRoutingEnabled();
    }
    return _platformService.isSmartRoutingEnabled();
  }

  @override
  Future<Either<Failure, bool>> isTelemetryEnabled() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.isTelemetryEnabled();
    }
    return _platformService.isTelemetryEnabled();
  }

  @override
  Future<Either<Failure, bool>> isOAuthLogin() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.isOAuthLogin();
    }
    return _platformService.isOAuthLogin();
  }

  @override
  Future<Either<Failure, String>> getOAuthProvider() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.getOAuthProvider();
    }
    return _platformService.getOAuthProvider();
  }

  @override
  Future<Either<Failure, String>> attachReferralCode(String code) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.attachReferralCode(code);
    }
    return _platformService.attachReferralCode(code);
  }

  @override
  Future<Either<Failure, List<String>>> getSplitTunnelItems(
    SplitTunnelFilterType type,
  ) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.getSplitTunnelItems(type);
    }
    return _platformService.getSplitTunnelItems(type);
  }

  @override
  Future<Either<Failure, Unit>> deletePrivateServerByName(String serverName) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.deletePrivateServerByName(serverName);
    }
    return _platformService.deletePrivateServerByName(serverName);
  }

  @override
  Future<Either<Failure, Unit>> updatePrivateServerName(
    String oldName,
    String newName,
  ) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.updatePrivateServerName(oldName, newName);
    }
    return _platformService.updatePrivateServerName(oldName, newName);
  }

  @override
  Future<Either<Failure, List<String>>> diagnosticLogFiles() {
    if (!PlatformUtils.isIOS) {
      throw UnimplementedError('diagnosticLogFiles is only supported on iOS');
    }
    return _platformService.diagnosticLogFiles();
  }

  @override
  Future<bool> checkVpnConflict() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.checkVpnConflict();
    }
    return _platformService.checkVpnConflict();
  }

  @override
  Future<Either<Failure, Unit>> patchSettings(Map<String, dynamic> updates) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.patchSettings(updates);
    }
    return _platformService.patchSettings(updates);
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSettings() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.getSettings();
    }
    return _platformService.getSettings();
  }

  @override
  Future<Either<Failure, Map<String, String>>> patchEnvVars(
    Map<String, String> updates,
  ) {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.patchEnvVars(updates);
    }
    return _platformService.patchEnvVars(updates);
  }

  @override
  Future<Either<Failure, Map<String, String>>> getEnvVars() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.getEnvVars();
    }
    return _platformService.getEnvVars();
  }

  @override
  Future<Either<Failure, Unit>> runURLTests() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.runURLTests();
    }
    return _platformService.runURLTests();
  }

  @override
  Future<Either<Failure, Unit>> sendConfigRequest() {
    if (PlatformUtils.isFFISupported) {
      return _ffiService.sendConfigRequest();
    }
    return _platformService.sendConfigRequest();
  }
}
