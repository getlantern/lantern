import 'dart:io';
import 'package:lantern/core/common/common.dart';
import 'package:window_manager/window_manager.dart';

Future<void> configureDesktopWindow() async {
  if (!PlatformUtils.isDesktop) return;

  await windowManager.ensureInitialized();

  final opts = const WindowOptions(
    size: desktopWindowSize,
    minimumSize: desktopWindowSize,
    maximumSize: desktopWindowSize,
    center: true,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.setResizable(false);
  await windowManager.setPreventClose(true);

  windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
