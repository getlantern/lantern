import 'package:flutter/services.dart';
import 'package:fpdart/src/either.dart';
import 'package:fpdart/src/unit.dart';
import 'package:lantern/lantern/lantern_core_service.dart';

class LanternPlatformService implements LanternCoreService {
  static const MethodChannel _methodChannel =
      MethodChannel('org.getlantern.lantern/method');

  @override
  void startVPN() {
    // TODO: implement startVPN
  }

  @override
  void stopVPN() {
    // TODO: implement stopVPN
  }

  @override
  Future<Either<String, Unit>> setupRadiance() {
    // TODO: implement setupRadiance
    throw UnimplementedError();
  }
}
