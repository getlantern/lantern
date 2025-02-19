import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/app.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:window_manager/window_manager.dart';

import 'core/localization/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  desktopInit();
  injectServices();
  await Future.microtask(Localization.loadTranslations);
  runApp(
    const ProviderScope(
      child: LanternApp(),
    ),
  );
}

Future<void> desktopInit() async {
  if (!PlatformUtils.isDesktop()) {
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.setSize(const ui.Size(360, 712));
}
