import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:lantern/core/common/common.dart';
import 'package:path/path.dart' as p;

/// Owns the WebView2 environment shared by every Windows webview in Lantern.
class AppWebViewEnvironment {
  static WebViewEnvironment? _environment;
  static Future<void>? _initialization;

  static WebViewEnvironment? get environment => _environment;

  /// Creates the shared Windows environment before the first webview mounts.
  static Future<void> initialize() {
    if (!PlatformUtils.isWindows) return Future.value();
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    var userDataFolder = '<unavailable>';
    try {
      userDataFolder = _userDataFolder(Platform.environment);
      final runtimeVersion = await WebViewEnvironment.getAvailableVersion();
      if (runtimeVersion == null) {
        throw StateError('WebView2 Runtime is unavailable');
      }

      _environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(userDataFolder: userDataFolder),
      );
      appLogger.info(
        'WebView2 environment ready: runtime=$runtimeVersion '
        'user_data_folder=$userDataFolder',
      );
    } catch (error, stackTrace) {
      appLogger.error(
        'Unable to initialize WebView2 with $userDataFolder',
        error,
        stackTrace,
      );
    }
  }

  static String _userDataFolder(Map<String, String> environment) {
    final configured = environment['WEBVIEW2_USER_DATA_FOLDER']?.trim();
    if (configured != null && configured.isNotEmpty) {
      return configured;
    }

    final localAppData = environment['LOCALAPPDATA']?.trim();
    if (localAppData == null || localAppData.isEmpty) {
      throw StateError('LOCALAPPDATA is unavailable');
    }
    return p.windows.join(localAppData, 'Lantern', 'WebView2');
  }
}
