import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('org.getlantern.lantern/native');

  // Method to start VPN
  Future<String?> startVPN() async {
    try {
      final String? result = await _channel.invokeMethod('startVPN');
      return result;
    } on PlatformException catch (e) {
      print("Failed to start VPN: '${e.message}'.");
      return null;
    }
  }

  // Method to stop VPN
  Future<String?> stopVPN() async {
    try {
      final String? result = await _channel.invokeMethod('stopVPN');
      return result;
    } on PlatformException catch (e) {
      print("Failed to stop VPN: '${e.message}'.");
      return null;
    }
  }

  // Method to check VPN status
  Future<int?> isVPNConnected() async {
    try {
      final int? status = await _channel.invokeMethod('isVPNConnected');
      return status;
    } on PlatformException catch (e) {
      print("Failed to check VPN status: '${e.message}'.");
      return null;
    }
  }
}
