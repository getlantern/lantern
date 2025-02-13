import 'package:flutter/material.dart';
import 'package:lantern/app.dart';
import 'package:lantern/core/utils/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'dart:ui' as ui;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktop()) {
    await windowManager.ensureInitialized();
    await windowManager.setSize(const ui.Size(360, 712));
  }

  runApp(
    const ProviderScope(
      child: LanternApp(),
    ),
  );
}
