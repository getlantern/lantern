import 'dart:io';

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_data.dart';

import 'package:lantern/core/services/injection_container.dart';

import 'package:lantern/core/models/mapper/plan_mapper.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/core/services/app_purchase.dart';

import 'package:lantern/lantern/lantern_core_service.dart';
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
  late final Stream<LanternStatus> _status;

  @override
  Future<void> init() async {
    appLogger.info(' LanternPlatformService');
    _status = statusChannel
        .receiveBroadcastStream()
        .map((event) => LanternStatus.fromJson(event));
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
  Stream<List<String>> logsStream() async* {
    throw UnimplementedError();
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
  Future<Either<Failure, Unit>> cancelSubscription() {
    // TODO: implement cancelSubscription
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> makeOneTimePayment({required String planID}) {
    // TODO: implement makeOneTimePayment
    throw UnimplementedError();
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
      {required StipeSubscriptionType type, required String planId}) async {
    try {
      final link = await _methodChannel
          .invokeMethod<String>('subscriptionPaymentRedirect', {
        "subType": type.name,
        "planId": planId,
      });
      return Right(link!);
    } catch (e, stackTrace) {
      appLogger.error('Error waking up LanternPlatformService', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> stipeSubscription(
      {required String planId}) async {
    try {
      final subData =
          await _methodChannel.invokeMethod<String>('stripeSubscription');
      final map = jsonDecode(subData!);
      return Right(map);
    } catch (e, stackTrace) {
      appLogger.error('Error waking up LanternPlatformService', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, PlansData>> plans() async {
    try {
      final subData = await _methodChannel.invokeMethod<String>('plans');
      final map = jsonDecode(subData!);
      final plans = PlansData.fromJson(map);
      sl<LocalStorageService>().savePlans(plans.toEntity());
      appLogger.info('Plans: $map');
      return Right(plans);
    } catch (e, stackTrace) {
      appLogger.error('Error waking up LanternPlatformService', e, stackTrace);
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
      appLogger.error('Error waking up LanternPlatformService', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, LoginResponse>> oAuthLoginCallback(
      String token) async {
    try {
      final bytes =
          await _methodChannel.invokeMethod('oauthLoginCallback', token);
      return Right(LoginResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error waking up LanternPlatformService', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, LoginResponse>> getUserData() async {
    try {
      final bytes = await _methodChannel.invokeMethod('getUserData');
      return Right(LoginResponse.fromBuffer(bytes));
    } catch (e, stackTrace) {
      appLogger.error('Error waking up LanternPlatformService', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }
}
