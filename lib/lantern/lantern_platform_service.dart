import 'package:flutter/services.dart';
import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/lantern/lantern_core_service.dart';

class LanternPlatformService implements LanternCoreService {
  static const MethodChannel _methodChannel =
      MethodChannel('org.getlantern.lantern/method');

  @override
  void startVPN() {
    try {
      _methodChannel.invokeMethod('startVPN');
    } on PlatformException catch (e) {
      appLogger.error('Error starting VPN: ${e.message}');
    }
  }

  @override
  void stopVPN() {
    try {
      _methodChannel.invokeMethod('startVPN');
    } on PlatformException catch (e) {
      appLogger.error('Error starting VPN: ${e.message}');
    }
  }

  @override
  Future<Either<String, Unit>> setupRadiance() {
    // TODO: implement setupRadiance
    throw UnimplementedError();
  }
}
