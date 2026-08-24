import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lantern/core/common/common.dart';
import 'package:window_manager/window_manager.dart';

/// Detects the case where the app is running but nothing ever reaches the
/// screen.
///
/// Flutter keeps building widgets, servicing platform channels and writing logs
/// on the UI thread while the rasterizer presents frames on another. When only
/// the latter fails the app looks healthy from Dart — every log line is normal
/// — and the user gets an empty window. That combination left
/// getlantern/engineering#3833 with nothing to go on but a screenshot.
///
/// Two signals are tracked because they fail independently: a post-frame
/// callback means the framework *built* a frame, while [firstFrameRasterized]
/// means one was actually *presented*. Built-but-never-presented points at the
/// GPU path rather than at Dart, which is the distinction that report needed.
class FirstFrameWatchdog {
  FirstFrameWatchdog._();

  static const _timeout = Duration(seconds: 10);

  static bool _started = false;
  static bool _built = false;
  static bool _recoveredFromTimeout = false;
  static Timer? _timer;

  /// Whether the watchdog gave up waiting and revealed the window itself.
  ///
  /// Once this is set the window is deliberately left closable, so a frame that
  /// arrives late must not re-arm close interception behind the user's back.
  static bool get recoveredFromTimeout => _recoveredFromTimeout;

  /// Starts watching. Idempotent: repeated calls are ignored rather than
  /// stacking a second timer on top of the first.
  static void start() {
    if (!PlatformUtils.isDesktop || _started) return;
    _started = true;

    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) => _built = true);
    _timer = Timer(_timeout, () => unawaited(_onTimeout()));
    unawaited(
      binding.waitUntilFirstFrameRasterized.then((_) {
        _timer?.cancel();
        _timer = null;
      }),
    );
  }

  static Future<void> _onTimeout() async {
    _timer = null;
    if (WidgetsBinding.instance.firstFrameRasterized) return;
    _recoveredFromTimeout = true;

    appLogger.error(
      'No frame presented after ${_timeout.inSeconds}s (frameBuilt=$_built). '
      'The window is blank. frameBuilt=true means the framework produced a '
      'frame the rasterizer never put on screen.',
    );

    try {
      // Reveal it, but closable. WindowWrapper never armed preventClose because
      // it waits on the same rasterization signal; this makes that explicit so
      // the user is never left with a blank window the close button ignores. A
      // blank window they can close is recoverable — no window is not, because
      // the single-instance handler re-activates this process on every relaunch
      // instead of starting a working one.
      await windowManager.setPreventClose(false);
      await windowManager.show();
    } catch (e, st) {
      appLogger.error('Failed to show window after first-frame timeout', e, st);
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _timer?.cancel();
    _timer = null;
    _started = false;
    _built = false;
    _recoveredFromTimeout = false;
  }
}
