import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/mapper/plan_mapper.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/models/private_server_status.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/lantern/lantern_core_service.dart';
import 'package:lantern/lantern/lantern_ffi_service.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

import '../core/models/lantern_status.dart';
import '../core/services/injection_container.dart' show sl;
import 'dart:async';

class LanternPlatformService implements LanternCoreService {

  LanternPlatformService();

  static const channelPrefix = 'org.getlantern.lantern';
  static const MethodChannel _methodChannel =
      MethodChannel('$channelPrefix/method');
  static const logsChannel = EventChannel("$channelPrefix/logs");
  static const EventChannel statusChannel =
      EventChannel("$channelPrefix/status", JSONMethodCodec());

  static const privateServerStatusChannel =
      EventChannel("$channelPrefix/private_server_status", JSONMethodCodec());
  late final Stream<LanternStatus> _status;
  late final Stream<PrivateServerStatus> _privateServerStatus;

  // We use this completer and future to explicitly have the native
  // side communicate that it is setup and ready.
  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  @override
  Future<void> init() async {
    appLogger.info(' LanternPlatformService');

    _status = statusChannel
        .receiveBroadcastStream()
        .map((event) => LanternStatus.fromJson(event));
    _privateServerStatus = privateServerStatusChannel
        .receiveBroadcastStream()
        .map((event) => PrivateServerStatus.fromJson(jsonDecode(event)));
    _methodChannel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'channelReady':
          appLogger.info('Channel is ready');
          _readyCompleter.complete();
        default:
          throw MissingPluginException('No handler for method ${call.method}');
      }
    });
  }

  @override
  Future<Either<Failure, String>> startVPN() async {
    try {
      final message = await invokeMethod<String>('startVPN');
      return Right(message!);
    } on PlatformException catch (ple) {
      return Left(Failure(
          error: ple.toString(),
          localizedErrorMessage: ple.localizedDescription));
    } catch (e, stackTrace) {
      appLogger.error('Error starting VPN Flutter', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> stopVPN() async {
    try {
      final message = await invokeMethod<String>('stopVPN');
      return Right('VPN stopped');
    } on PlatformException catch (ple) {
      return Left(ple.toFailure());
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    return _status;
  }

  @override
  Stream<List<String>> watchLogs(String path) async* {
    yield* logsChannel
        .receiveBroadcastStream()
        .map((event) => (event as List).map((e) => e as String).toList());
  }

  @override
  Stream<List<AppData>> appsDataStream() async* {
    if (Platform.isAndroid) {
      yield* androidAppsDataStream();
    } else if (Platform.isMacOS) {
      yield* macAppsDataStream();
    } else {
      throw UnimplementedError();
    }
  }

  List<AppData> _mapToAppData(
    Iterable<Map<String, dynamic>> rawApps,
    Set<String> enabledAppNames,
  ) {
    return rawApps.map((raw) {
      final isEnabled = enabledAppNames.contains(raw["name"]);
      return AppData(
        name: raw["name"] as String,
        bundleId: raw["bundleId"] as String,
        appPath: raw["appPath"] as String? ?? '',
        iconPath: raw["iconPath"] as String? ?? '',
        iconBytes: raw["icon"] as Uint8List?,
        isEnabled: isEnabled,
      );
    }).toList();
  }

  Set<String> _getEnabledAppNames() {
    final LocalStorageService db = sl<LocalStorageService>();
    final savedApps = db.getAllApps();
    return savedApps
        .where((app) => app.isEnabled)
        .map((app) => app.name)
        .toSet();
  }

  Stream<List<AppData>> androidAppsDataStream() async* {
    if (!Platform.isAndroid) {
      throw UnimplementedError();
    }
    try {
      final apps = await InstalledApps.getInstalledApps(true, true);
      final enabledAppNames = _getEnabledAppNames();
      final rawApps = apps.map((app) => {
            "name": app.name,
            "bundleId": app.packageName,
            "appPath": "",
            "icon": app.icon,
          });
      yield _mapToAppData(rawApps, enabledAppNames);
    } catch (e, st) {
      appLogger.error("Failed to fetch installed apps", e, st);
      yield [];
    }
  }

  Stream<List<AppData>> macAppsDataStream() async* {
    try {
      final String? json =
          await invokeMethod<String>("installedApps");
      if (json == null) {
        yield [];
        return;
      }
      final decoded = jsonDecode(json) as List<dynamic>;
      final enabledAppNames = _getEnabledAppNames();
      final rawApps = decoded.cast<Map<String, dynamic>>();
      yield _mapToAppData(rawApps, enabledAppNames);
    } catch (e, st) {
      appLogger.error("Failed to fetch installed apps", e, st);
      yield [];
    }
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
      SplitTunnelFilterType type, String value) async {
    try {
      await invokeMethod('addSplitTunnelItem', {
        'filterType': type.value,
        'value': value,
      });
      return right(unit);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
      SplitTunnelFilterType type, String value) async {
    try {
      await invokeMethod('removeSplitTunnelItem', {
        'filterType': type.value,
        'value': value,
      });
      return right(unit);
    } catch (e) {
      return Left(e.toFailure());
    }
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
    try {
      await invokeMethod('reportIssue', {
        'email': email,
        'issueType': issueType,
        'description': description,
        'device': device,
        'model': model,
        'logFilePath': logFilePath,
      });
      return right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error reporting issue', e, stackTrace);
      return left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> isVPNConnected() async {
    try {
      await invokeMethod('isVPNConnected');
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error waking up LanternPlatformService', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> startInAppPurchaseFlow(
      {required String planId,
      required PaymentSuccessCallback onSuccess,
      required PaymentErrorCallback onError}) async {
    try {
      await sl<AppPurchase>().startSubscription(
        plan: planId,
        onSuccess: onSuccess,
        onError: onError,
      );
      return Right(unit);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> stipeSubscriptionPaymentRedirect(
      {required BillingType type,
      required String planId,
      required String email}) async {
    throw UnimplementedError("This not supported on mobile");
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription(
      {required String planId, required String email}) async {
    try {
      final subData =
          await invokeMethod<String>('stripeSubscription', {
        "planId": planId,
        "email": email,
      });
      final map = jsonDecode(subData!);
      return Right(map);
    } catch (e) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, String>> stripeBillingPortal() async {
    try {
      final url =
          await invokeMethod<String>('stripeBillingPortal');
      return Right(url!);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, PlansData>> plans() async {
    try {
      final channel = isStoreVersion() ? 'store' : 'non-store';
      final subData =
          await invokeMethod<String>('plans', channel);
      final map = jsonDecode(subData!);
      final plans = PlansData.fromJson(map);
      sl<LocalStorageService>().savePlans(plans.toEntity());
      appLogger.info('Plans: $map');
      return Right(plans);
    } catch (e, stackTrace) {
      appLogger.error('Error fetching plans', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, String>> getOAuthLoginUrl(String provider) async {
    try {
      final loginUrl =
          await invokeMethod<String>('oauthLoginUrl', provider);
      return Right(loginUrl!);
    } catch (e) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, UserResponse>> oAuthLoginCallback(String token) async {
    try {
      final bytes =
          await invokeMethod('oauthLoginCallback', token);
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error handling OAuth login callback', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, UserResponse>> getUserData() async {
    try {
      final bytes = await invokeMethod('getUserData');
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error fetching user data', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  // Only supported in IOS
  @override
  Future<Either<Failure, Unit>> showManageSubscriptions() async {
    try {
      await invokeMethod('showManageSubscriptions');
      return Right(unit);
    } catch (e) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, UserResponse>> fetchUserData() async {
    try {
      final userBytes = await invokeMethod('fetchUserData');
      return Right(UserResponse.fromBuffer(userBytes));
    } catch (e, stackTrace) {
      appLogger.error("error fetching user data", e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, Unit>> acknowledgeInAppPurchase(
      {required String purchaseToken, required String planId}) async {
    try {
      await invokeMethod('acknowledgeInAppPurchase', {
        'purchaseToken': purchaseToken,
        'planId': planId,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error acknowledging in-app purchase', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, DataCapInfo>> fetchDataCapInfo() async {
    try {
      final json =
          await invokeMethod<String>('fetchDataCapInfo');
      final map = jsonDecode(jsonEncode(json));
      final dataCap = DataCapInfo.fromJson(map);
      return Right(dataCap);
    } catch (e, st) {
      appLogger.error('fetchDataCapInfo failed', e, st);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> paymentRedirect(
      {required String provider,
      required String planId,
      required String email}) async {
    if (PlatformUtils.isIOS) {
      throw UnimplementedError("This not supported on IOS");
    }
    try {
      final redirectUrl =
          await invokeMethod<String>('paymentRedirect', {
        'provider': provider,
        'planId': planId,
        'email': email,
      });
      return Right(redirectUrl!);
    } catch (e, stackTrace) {
      appLogger.error('Error getting payment redirect URL', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, UserResponse>> login(
      {required String email, required String password}) async {
    try {
      final bytes = await invokeMethod('login', {
        'email': email,
        'password': password,
      });
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error logging', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> logout(String email) async {
    try {
      final bytes = await invokeMethod('logout', email);
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error logging out', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email) async {
    try {
      await invokeMethod('startRecoveryByEmail', {
        'email': email,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error starting recovery by email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> validateRecoveryCode(
      {required String email, required String code}) async {
    try {
      await invokeMethod('validateRecoveryCode', {
        'email': email,
        'code': code,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error validating recovery code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> completeRecoveryByEmail({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await invokeMethod('completeRecoveryByEmail', {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error completing change email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> signUp(
      {required String email, required String password}) async {
    try {
      await invokeMethod('signUp', {
        'email': email,
        'password': password,
      });

      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error signing up', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, UserResponse>> deleteAccount(
      {required String email, required String password}) async {
    try {
      final bytes = await invokeMethod('deleteAccount', {
        'email': email,
        'password': password,
      });
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error deleting account', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> activationCode(
      {required String email, required String resellerCode}) async {
    try {
      await invokeMethod('activationCode', {
        'email': email,
        'resellerCode': resellerCode,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error activating code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> digitalOceanPrivateServer() async {
    try {
      await invokeMethod('digitalOcean');
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error activating code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> googleCloudPrivateServer() async {
    try {
      await invokeMethod('googleCloud');
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error activating code', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Stream<PrivateServerStatus> watchPrivateServerStatus() {
    return _privateServerStatus;
  }

  @override
  Future<Either<Failure, Unit>> setUserInput(
      {required PrivateServerInput methodType, required String input}) async {
    try {
      await invokeMethod(methodType.name, input);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error setting user input', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> startDeployment(
      {required String location, required String serverName}) async {
    try {
      await invokeMethod('startDeployment', {
        'location': location,
        'serverName': serverName,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error starting deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> cancelDeployment() async {
    try {
      await invokeMethod('cancelDeployment');
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error canceling deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setCert({required String fingerprint}) async {
    try {
      await invokeMethod('selectCertFingerprint', fingerprint);
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error canceling deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> addServerManually(
      {required String ip,
      required String port,
      required String accessToken,
      required String serverName}) async {
    try {
      await invokeMethod('addServerManually', {
        'ip': ip,
        'port': port,
        'accessToken': accessToken,
        'serverName': serverName,
      });
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error canceling deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> connectToServer(
      String location, String tag) async {
    try {
      await invokeMethod('connectToServer', {
        'location': location,
        'tag': tag,
      });
      return Right("ok");
    } catch (e) {
      appLogger.debug('Error setting private server');
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> inviteToServerManagerInstance(
      {required String ip,
      required String port,
      required String accessToken,
      required String inviteName}) async {
    try {
      final inviteCode = await invokeMethod<String>(
        'inviteToServerManagerInstance',
        {
          'ip': ip,
          'port': port,
          'accessToken': accessToken,
          'inviteName': inviteName,
        },
      );
      return Right(inviteCode!);
    } catch (e, stackTrace) {
      appLogger.error(
          'Error inviting to server manager instance', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> revokeServerManagerInstance(
      {required String ip,
      required String port,
      required String accessToken,
      required String inviteName}) async {
    try {
      final result = await invokeMethod<String>(
        'revokeServerManagerInstance',
        {
          'ip': ip,
          'port': port,
          'accessToken': accessToken,
          'inviteName': inviteName,
        },
      );
      return Right('ok');
    } catch (e, stackTrace) {
      appLogger.error('Error revoking server manager instance', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> featureFlag() async {
    try {
      final featureFlag =
          await invokeMethod<String>('featureFlag');
      return Right(featureFlag!);
    } catch (e, stackTrace) {
      appLogger.error('Error fetching feature flag', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, AvailableServers>> getLanternAvailableServers() async {
    try {
      final result =
          await invokeMethod('getLanternAvailableServers');
      return Right(AvailableServers.fromJson(jsonDecode(result)));
    } catch (e, stackTrace) {
      appLogger.error(
          'Error fetching Lantern available servers', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> deviceRemove(
      {required String deviceId}) async {
    try {
      final result = await invokeMethod<String>('removeDevice', {
        'deviceId': deviceId,
      });
      return Right(result!);
    } catch (e, stackTrace) {
      appLogger.error('Error removing device', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> startChangeEmail(
      String newEmail, String password) async {
    try {
      final result =
          await invokeMethod<String>('startChangeEmail', {
        'newEmail': newEmail,
        'password': password,
      });
      return Right(result!);
    } catch (e, stackTrace) {
      appLogger.error('Error starting change email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> completeChangeEmail(
      {required String newEmail,
      required String password,
      required String code}) async {
    try {
      final result =
          await invokeMethod<String>('completeChangeEmail', {
        'newEmail': newEmail,
        'password': password,
        'code': code,
      });
      return right(result!);
    } catch (e, stackTrace) {
      appLogger.error('Error completing change email', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, String>> getAutoServerLocation() async {
    try {
      final result =
          await invokeMethod<String>('getAutoServerLocation');
      return right(result!);
    } catch (e, stackTrace) {
      appLogger.error('Error fetching auto server location', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    // Make sure the native code has signalled that it's setup and ready
    await ready;
    return _methodChannel.invokeMethod<T>(method, arguments);
  }
}
