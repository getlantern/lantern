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

  // Applies the sizing options but deliberately does not show the window, and
  // does not arm preventClose. Both are deferred to WindowWrapper, which runs
  // once the widget tree exists:
  //
  //  - Showing here puts a window on screen before runApp() has produced a
  //    frame, so a failure to render reaches the user as an empty grey window
  //    rather than as an app that simply has not opened yet.
  //  - preventClose suppresses the native destroy and hands the close request
  //    to a Dart listener. Armed before that listener is registered, it leaves
  //    the window impossible to close at all.
  //
  // See getlantern/engineering#3833.
  await windowManager.waitUntilReadyToShow(opts);
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
