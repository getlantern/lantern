import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/lantern_app.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'core/common/app_secrets.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  widgetsBinding.deferFirstFrame();
  initLogger();
  await _loadAppSecrets();
  desktopInit();
  await injectServices();
  await Future.microtask(Localization.loadTranslations);
  widgetsBinding.allowFirstFrame();
  await SentryFlutter.init((options) {
    // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
    // We recommend adjusting this value in production.
    options.tracesSampleRate = 1.0;
    // The sampling rate for profiling is relative to tracesSampleRate
    // Setting to 1.0 will profile 100% of sampled transactions:
    options.profilesSampleRate = 1.0;
    options.environment = kReleaseMode ? "production" : "development";
    options.dsn = kReleaseMode ? AppSecrets.dnsConfig() : "";
    options.enableNativeCrashHandling = true;
    options.attachStacktrace = true;
    options.enableAutoNativeBreadcrumbs = true;
    options.enableNdkScopeSync = true;
  }, appRunner: () => buildApp());
}

void buildApp() {
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
