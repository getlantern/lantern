import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern_app.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  widgetsBinding.deferFirstFrame();
  initLogger();
  await _loadAppSecrets();
  desktopInit();
  await injectServices();
  await Future.microtask(Localization.loadTranslations);
  widgetsBinding.allowFirstFrame();
  runApp(
    DevicePreview(
        enabled: false,
        builder: (context) => const ProviderScope(
              child: LanternApp(),
            )),
  );

}

Future<void> desktopInit() async {
  if (!PlatformUtils.isDesktop()) {
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.setSize(desktopWindowSize);
  windowManager.setResizable(false);
}

Future<void> _loadAppSecrets() async {
  try {
    await dotenv.load(fileName: "app.env");
    appLogger.debug('App secrets loaded');
  } catch (e) {
    appLogger.error("Error loading app secrets: $e");
  }
}
