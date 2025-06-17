import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';
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

class LanternPlatformService implements LanternCoreService {
  final AppPurchase appPurchase;

  LanternPlatformService(this.appPurchase);

  static const channelPrefix = 'org.getlantern.lantern';
  static const MethodChannel _methodChannel =
      MethodChannel('org.getlantern.lantern/method');
  static const logsChannel = EventChannel("$channelPrefix/logs");
  static const statusChannel =
      EventChannel("$channelPrefix/status", JSONMethodCodec());
  static const privateServerStatusChannel =
      EventChannel("$channelPrefix/private_server_status", JSONMethodCodec());
  late final Stream<LanternStatus> _status;
  late final Stream<PrivateServerStatus> _privateServerStatus;

  @override
  Future<void> init() async {
    appLogger.info(' LanternPlatformService');
    _status = statusChannel
        .receiveBroadcastStream()
        .map((event) => LanternStatus.fromJson(event));
    _privateServerStatus =
        privateServerStatusChannel.receiveBroadcastStream().map(
      (event) {
        final map = jsonDecode(event);
        return PrivateServerStatus.fromJson(map);
      },
    );
  }

  @override
  Future<Either<Failure, String>> startVPN() async {
    try {
      final message = await _methodChannel.invokeMethod<String>('startVPN');
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
      final message = await _methodChannel.invokeMethod<String>('stopVPN');
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
    if (!Platform.isAndroid) {
      throw UnimplementedError();
    }
    try {
      final apps = await InstalledApps.getInstalledApps(true, true);
      final LocalStorageService db = sl<LocalStorageService>();
      final savedApps = db.getAllApps();
      final enabledAppNames = savedApps
          .where((app) => app.isEnabled)
          .map((app) => app.name)
          .toSet();
      yield apps.map((appInfo) {
        final isEnabled = enabledAppNames.contains(appInfo.name);
        return AppData(
          name: appInfo.name,
          bundleId: appInfo.packageName,
          iconBytes: appInfo.icon,
          appPath: '',
          isEnabled: isEnabled,
        );
      }).toList();
    } catch (e, st) {
      appLogger.error("Failed to fetch installed apps", e, st);
      yield [];
    }
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
      SplitTunnelFilterType type, String value) async {
    try {
      await _methodChannel.invokeMethod('addSplitTunnelItem', {
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
      await _methodChannel.invokeMethod('removeSplitTunnelItem', {
        'filterType': type.value,
        'value': value,
      });
      return right(unit);
    } catch (e) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> isVPNConnected() async {
    try {
      await _methodChannel.invokeMethod('isVPNConnected');
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
      await appPurchase.startSubscription(
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
          await _methodChannel.invokeMethod<String>('stripeSubscription', {
        "planId": planId,
        "email": email,
      });
      final map = jsonDecode(subData!);
      return Right(map);
    } catch (e, stackTrace) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, String>> stripeBillingPortal() async {
    try {
      final url =
          await _methodChannel.invokeMethod<String>('stripeBillingPortal');
      return Right(url!);
    } catch (e, stackTrace) {
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, PlansData>> plans() async {
    try {
      final channel = isStoreVersion() ? 'store' : 'non-store';
      final subData =
          await _methodChannel.invokeMethod<String>('plans', channel);
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
          await _methodChannel.invokeMethod<String>('oauthLoginUrl', provider);
      return Right(loginUrl!);
    } catch (e, stackTrace) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, UserResponse>> oAuthLoginCallback(String token) async {
    try {
      final bytes =
          await _methodChannel.invokeMethod('oauthLoginCallback', token);
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
      final bytes = await _methodChannel.invokeMethod('getUserData');
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
      await _methodChannel.invokeMethod('showManageSubscriptions');
      return Right(unit);
    } catch (e, stackTrace) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, UserResponse>> fetchUserData() async {
    try {
      final userBytes = await _methodChannel.invokeMethod('fetchUserData');
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
      await _methodChannel.invokeMethod('acknowledgeInAppPurchase', {
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
  Future<Either<Failure, String>> paymentRedirect(
      {required String provider,
      required String planId,
      required String email}) async {
    if (PlatformUtils.isIOS) {
      throw UnimplementedError("This not supported on IOS");
    }
    try {
      final redirectUrl =
          await _methodChannel.invokeMethod<String>('paymentRedirect', {
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
      final bytes = await _methodChannel.invokeMethod('login', {
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
      final bytes = await _methodChannel.invokeMethod('logout', email);
      return Right(UserResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error logging out', e, stackTrace);
      return Left(e.toFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> startRecoveryByEmail(String email) async {
    try {
      await _methodChannel.invokeMethod('startRecoveryByEmail', {
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
      await _methodChannel.invokeMethod('validateRecoveryCode', {
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
  Future<Either<Failure, Unit>> completeChangeEmail({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _methodChannel.invokeMethod('completeChangeEmail', {
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
      await _methodChannel.invokeMethod('signUp', {
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
      final bytes = await _methodChannel.invokeMethod('deleteAccount', {
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
      await _methodChannel.invokeMethod('activationCode', {
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
      await _methodChannel.invokeMethod('digitalOcean');
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
      await _methodChannel.invokeMethod(methodType.name, input);
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
      await _methodChannel.invokeMethod('startDeployment', {
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
      await _methodChannel.invokeMethod('cancelDeployment');
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error canceling deployment', e, stackTrace);
      return Left(e.toFailure());
    }
  }
}
