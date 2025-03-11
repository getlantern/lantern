import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

import '../../core/services/logger_service.dart';

class ProtocolRegistrar {
  ProtocolRegistrar._();

  /// The shared instance of [ProtocolRegistrar].
  static final ProtocolRegistrar instance = ProtocolRegistrar._();

  /// Registers the given [scheme] as a protocol handler.
  Future<void> register(String scheme) async {
    try {
      appLogger.debug("Windows protocol registration for $scheme");
      String appPath = Platform.resolvedExecutable;

      String protocolRegKey = 'Software\\Classes\\$scheme';
      RegistryValue protocolRegValue = const RegistryValue(
        'URL Protocol',
        RegistryValueType.string,
        '',
      );
      String protocolCmdRegKey = 'shell\\open\\command';
      RegistryValue protocolCmdRegValue = RegistryValue(
        '',
        RegistryValueType.string,
        '"$appPath" "%1"',
      );

      final regKey = Registry.currentUser.createKey(protocolRegKey);
      regKey.createValue(protocolRegValue);
      regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
      appLogger.debug('Windows protocol registration for $scheme completed');
      regKey.close();
    } catch (e) {
      appLogger.error("Error registering protocol: $e");
    }
  }
}
