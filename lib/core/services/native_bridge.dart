import 'package:flutter/services.dart';
import 'package:lantern/core/services/logger_service.dart';

// This class provides a bridge between Flutter and the native iOS VPN
// implementation using a MethodChannel.
class NativeBridge {
  static const MethodChannel _channel =
      MethodChannel('org.getlantern.lantern/native');

  // Calls the native iOS method to start the VPN connection.
  Future<String?> startVPN() async {
    try {
      await _channel.invokeMethod('startVPN');
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Unknown error occurred (startVPN)';
    }
  }

  // Calls the native iOS method to stop the VPN connection.
  Future<String?> stopVPN() async {
    try {
      await _channel.invokeMethod('stopVPN');
      return null;
    } on PlatformException catch (e) {
      return e.message ?? 'Unknown error occurred (stopVPN)';
    }
  }

  Future<int?> isVPNConnected() async {
    try {
      final int? status = await _channel.invokeMethod('isVPNConnected');
      return status;
    } on PlatformException catch (e) {
      appLogger.error("Failed to check VPN status: '${e.message}'.");
      return null;
    }
  }
}
