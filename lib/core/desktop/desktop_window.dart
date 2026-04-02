import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:lantern/core/common/common.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

Future<void> configureDesktopWindow() async {
  if (!PlatformUtils.isDesktop) return;

  await windowManager.ensureInitialized();
  final size = await _boundedInitialSize();
  final minSize = Size(
    math.min(desktopWindowMinSize.width, size.width),
    math.min(desktopWindowMinSize.height, size.height),
  );

  final opts = WindowOptions(
    size: size,
    minimumSize: minSize,
    maximumSize: size,
    center: true,
    titleBarStyle: TitleBarStyle.normal,
    title: PlatformUtils.isWindows ? 'Lantern' : "",
  );

  await windowManager.setResizable(true);
  await windowManager.setPreventClose(true);

  windowManager.waitUntilReadyToShow(opts, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<Size> _boundedInitialSize() async {
  try {
    final display = await screenRetriever.getPrimaryDisplay();
    final visibleSize = display.visibleSize ?? display.size;
    return Size(
      math.min(desktopWindowSize.width, visibleSize.width),
      math.min(desktopWindowSize.height, visibleSize.height),
    );
  } catch (_) {
    return desktopWindowSize;
  }
}
