import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';

/// Local SOCKS/HTTP proxy endpoint for stealth-novpn builds. The listen port is
/// user-editable (persisted) and applied to radiance via
/// LanternService.setProxyListenPort before connecting.
class StealthNoVpnProxy {
  static const host = '127.0.0.1';

  /// Must match BuildConfig.STEALTH_NO_VPN_PROXY_PORT (the SOCKS listener
  /// fallback when the user has not overridden the port).
  static const defaultPort = 14986;

  static const portKey = 'novpn_proxy_listen_port';

  static int get port {
    final raw = sl<LocalStorageService>().getString(portKey);
    final parsed = int.tryParse(raw ?? '');
    if (parsed != null && parsed > 0 && parsed <= 65535) {
      return parsed;
    }
    return defaultPort;
  }

  static String get address => '$host:$port';

  static Future<void> setPort(int value) async {
    await sl<LocalStorageService>().setString(portKey, value.toString());
  }
}
