import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/app_window.dart';
import 'package:window_manager/window_manager.dart';

Future<void> configureDesktopWindow() async {
  if (!PlatformUtils.isDesktop) return;

  final window = AppWindow.instance.window;
  if (window == null) return;

  final size = _boundedInitialSize();
  final minSize = Size(
    math.min(desktopWindowMinSize.width, size.width),
    math.min(desktopWindowMinSize.height, size.height),
  );

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
  window.isResizable = true;
  window.titleBarStyle = TitleBarStyle.normal;
  window.setSize(size.toNative(), false);
  window.center();
  window.minimumSize = minSize.toNative();
  window.maximumSize = size.toNative();
  window.title = PlatformUtils.isWindows ? 'Lantern' : "";
}

Size _boundedInitialSize() {
  try {
    final visibleSize = AppWindow.instance.primaryWorkArea();
    if (visibleSize == null) return desktopWindowSize;
    return Size(
      math.min(desktopWindowSize.width, visibleSize.width),
      math.min(desktopWindowSize.height, visibleSize.height),
    );
  } catch (_) {
    return desktopWindowSize;
  }
}
