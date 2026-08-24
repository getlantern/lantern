import 'dart:async';
import 'dart:ui' show FrameTiming;

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
/// callback means the framework *built* a frame, a frame timing means one was
/// actually rasterized and *presented*. Built-but-never-presented points at the
/// GPU path rather than at Dart, which is the distinction that report needed.
class FirstFrameWatchdog {
  FirstFrameWatchdog._();

  static const _timeout = Duration(seconds: 10);

  static bool _built = false;
  static bool _presented = false;
  static Timer? _timer;

  /// Starts watching. Call once, after the binding is initialized and before
  /// [runApp]. No-op off desktop, where this failure mode has not been seen.
  static void start() {
    if (!PlatformUtils.isDesktop) return;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) => _built = true);
    binding.addTimingsCallback(_onTimings);
    _timer = Timer(_timeout, () => unawaited(_onTimeout()));
  }

  static void _onTimings(List<FrameTiming> timings) {
    if (_presented || timings.isEmpty) return;
    _presented = true;
    _stopWatching();
  }

  static void _stopWatching() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
  }

  static Future<void> _onTimeout() async {
    if (_presented) return;
    _stopWatching();
    appLogger.error(
      'No frame presented after ${_timeout.inSeconds}s (frameBuilt=$_built). '
      'The window is blank. frameBuilt=true means the framework produced a '
      'frame the rasterizer never put on screen.',
    );
    // Show it regardless. A blank window the user can close is recoverable; no
    // window at all is not, because the single-instance handler re-activates
    // this process on every relaunch instead of starting a working one.
    try {
      await windowManager.show();
    } catch (e, st) {
      appLogger.error('Failed to show window after first-frame timeout', e, st);
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _stopWatching();
    _built = false;
    _presented = false;
  }
}
