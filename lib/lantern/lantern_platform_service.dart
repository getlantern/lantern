import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/app_purchase.dart';
import 'package:lantern/core/extensions/error.dart';
import 'package:lantern/core/models/app_data.dart';
import 'package:lantern/lantern/lantern_core_service.dart';

import '../core/models/lantern_status.dart';

class LanternPlatformService implements LanternCoreService {
  final AppPurchase appPurchase;

  LanternPlatformService(this.appPurchase);

  static const MethodChannel _methodChannel =
      MethodChannel('org.getlantern.lantern/method');

  static const statusChannel =
      EventChannel("org.getlantern.lantern/status", JSONMethodCodec());
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
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Future<Either<Failure, String>> stopVPN() async {
    try {
      final message = await _methodChannel.invokeMethod<String>('stopVPN');
      return Right('VPN stopped');
    } on PlatformException catch (ple) {
      return Left(Failure(
          error: ple.toString(),
          localizedErrorMessage: ple.localizedDescription));
    } catch (e, stackTrace) {
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
    }
  }

  @override
  Stream<LanternStatus> watchVPNStatus() {
    return _status;
  }

  @override
  Stream<List<AppData>> appsDataStream() async* {
    throw UnimplementedError();
  }

  @override
  Stream<List<String>> logsStream() async* {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> addSplitTunnelItem(
      SplitTunnelFilterType type, String value) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> removeSplitTunnelItem(
      SplitTunnelFilterType type, String value) {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, Unit>> isVPNConnected() async {
    try {
      await _methodChannel.invokeMethod('isVPNConnected');
      return Right(unit);
    } catch (e, stackTrace) {
      appLogger.error('Error waking up LanternPlatformService', e, stackTrace);
      return Left(Failure(
          error: e.toString(),
          localizedErrorMessage: (e as Exception).localizedDescription));
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
  Future<Either<Failure, Unit>> startSubscriptionFlow(
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
      return Left(Failure(
        error: e.toString(),
        localizedErrorMessage: (e as Exception).localizedDescription,
      ));
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
}
