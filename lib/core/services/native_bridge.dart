import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('org.getlantern.lantern/native');

  // Method to start VPN
  Future<String?> startVPN() async {
    try {
      await _channel.invokeMethod('startVPN');
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Unknown error occurred (startVPN)';
    }
  }

  // Method to stop VPN
  Future<String?> stopVPN() async {
    try {
      await _channel.invokeMethod('stopVPN');
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Unknown error occurred (stopVPN)';
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
