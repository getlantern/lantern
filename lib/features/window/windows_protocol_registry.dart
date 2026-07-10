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
      String protocolCmdRegKey = 'shell\\open\\command';

      final regKey = CURRENT_USER.create(protocolRegKey);
      try {
        regKey.setValue('URL Protocol', const RegistryValue.string(''));
        final cmdKey = regKey.create(protocolCmdRegKey);
        try {
          cmdKey.setValue('', RegistryValue.string('"$appPath" "%1"'));
        } finally {
          cmdKey.close();
        }
        appLogger.debug('Windows protocol registration for $scheme completed');
      } finally {
        regKey.close();
      }
    } catch (e) {
      appLogger.error("Error registering protocol: $e");
    }
  }
}
