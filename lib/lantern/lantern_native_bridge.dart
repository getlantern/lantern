import 'package:flutter/services.dart';
import 'package:lantern/lantern/lantern_core_service.dart';

class LanternNativeBridge implements LanternCoreService{
  static const MethodChannel _channel = MethodChannel('org.getlantern.lantern/native');
  @override
  void startVPN() {
    // TODO: implement startVPN
  }

  @override
  void stopVPN() {
    // TODO: implement stopVPN
  }

  @override
  void setupRadiance() {
    // TODO: implement setupRadiance
  }

}