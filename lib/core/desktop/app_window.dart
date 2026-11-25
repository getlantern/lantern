import 'dart:ui' show Brightness, Size;

import 'package:flutter/foundation.dart';
import 'package:nativeapi/nativeapi.dart' as nativeapi;
import 'package:window_manager/window_manager.dart';

/// The app's one desktop window, on window_manager's native API.
class AppWindow {
  AppWindow._();

  static final AppWindow instance = AppWindow._();

  /// Replaces the platform window lookup in tests.
  @visibleForTesting
  Window? Function()? debugWindow;

  /// Replaces the primary display's work area in tests.
  @visibleForTesting
  Size? Function()? debugWorkArea;

  /// Whether the close button hides the window instead of closing it.
  bool preventClose = false;

  final _focused = _Signal();
  final _changed = _Signal();

  /// Fires when the window gains focus.
  Listenable get focused {
    window;
    return _focused;
  }

  /// Fires when the window may have been shown, hidden, minimized or restored.
  Listenable get changed {
    window;
    return _changed;
  }

  Window? _window;
  Window? _listening;
  bool _closing = false;

  /// The window, or null while the platform has none to give. Looking it up
  /// is what attaches the event listener.
  Window? get window {
    final override = debugWindow;
    final window = override != null ? override() : (_window ??= _current());
    if (window != null && !identical(window, _listening)) {
      _listening = window;
      _closing = false;
      window.addListener(_onEvent);
    }
    return window;
  }

  static Window? _current() {
    try {
      return WindowManager.instance.getCurrent();
    } on ArgumentError {
      // No native library, as in a plain Dart VM.
      return null;
    }
  }

  /// Whether the window is on screen: not hidden (closed to the tray) or
  /// minimized. Assumes it is when there is no window to ask.
  bool get isShown {
    final window = this.window;
    if (window == null) return true;
    return window.isVisible && !window.isMinimized;
  }

  /// Shows the window, restoring it if minimized. False when there is none.
  bool show({bool focus = true}) {
    final window = this.window;
    if (window == null) return false;
    final wasVisible = window.isVisible;
    if (window.isMinimized) window.restore();
    window.show();
    if (focus) window.focus();
    // The platform reports no show or hide of its own.
    if (!wasVisible) _changed.fire();
    return true;
  }

  void hide() {
    final window = this.window;
    if (window == null) return;
    // macOS reports a minimized window as not visible.
    final wasShown = window.isVisible || window.isMinimized;
    window.hide();
    if (wasShown) _changed.fire();
  }

  /// Closes the window for good, past [preventClose].
  void destroy() {
    final window = this.window;
    if (window == null) return;
    _closing = true;
    if (!window.close()) _closing = false;
  }

  /// Whether the window has an entry in the taskbar or Dock.
  set visibleInTaskbar(bool visible) => window?.isVisibleInTaskbar = visible;

  /// Light or dark window chrome.
  void setBrightness(Brightness brightness) {
    nativeapi.Application.instance.setBrightness(switch (brightness) {
      Brightness.light => nativeapi.Brightness.light,
      Brightness.dark => nativeapi.Brightness.dark,
    });
  }

  /// The primary display's usable size, or null when it can't be read.
  Size? primaryWorkArea() {
    final override = debugWorkArea;
    if (override != null) return override();
    final display = nativeapi.DisplayManager.instance.getPrimary();
    if (display == null) return null;
    try {
      final area = display.workArea;
      return Size(area.width, area.height);
    } finally {
      display.dispose();
    }
  }

  void _onEvent(WindowEvent event) {
    switch (event) {
      case WindowCloseRequestedEvent(:final request):
        if (_closing || !preventClose) return;
        request.cancel();
        hide();
      case WindowFocusedEvent():
        _focused.fire();
        _changed.fire();
      // Windows restores a maximized window from minimized as a maximize.
      case WindowMinimizedEvent() ||
          WindowRestoredEvent() ||
          WindowMaximizedEvent():
        _changed.fire();
      default:
        break;
    }
  }
}

class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}
