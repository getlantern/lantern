import 'dart:async';

import 'package:nativeapi/nativeapi.dart' as nativeapi;

/// A desktop window simulated in Dart that records what is asked of it.
class FakeNativeWindow extends nativeapi.Window {
  FakeNativeWindow() : super.borrowed(0);

  final List<String> calls = <String>[];
  bool visible = false;
  bool minimized = false;
  FutureOr<void> Function(nativeapi.WindowEvent)? _listener;

  /// Delivers [event] as the platform would.
  void fire(nativeapi.WindowEvent event) => _listener?.call(event);

  @override
  bool get isVisible => visible;
  @override
  bool get isMinimized => minimized;

  @override
  void show() {
    calls.add('show');
    visible = true;
  }

  @override
  void hide() {
    calls.add('hide');
    visible = false;
  }

  @override
  void restore() => minimized = false;
  @override
  void focus() => calls.add('focus');
  @override
  void center() => calls.add('center');
  @override
  bool close() {
    calls.add('close');
    return true;
  }

  @override
  void setSize(nativeapi.Size size, bool animate) => calls.add('setSize');

  @override
  set minimumSize(nativeapi.Size value) => calls.add('setMinimumSize');
  @override
  set maximumSize(nativeapi.Size value) => calls.add('setMaximumSize');
  @override
  set isResizable(bool value) => calls.add('setResizable');
  @override
  set title(String value) => calls.add('setTitle');
  @override
  set titleBarStyle(nativeapi.TitleBarStyle value) =>
      calls.add('setTitleBarStyle');
  @override
  set isVisibleInTaskbar(bool value) => calls.add('setVisibleInTaskbar');

  @override
  nativeapi.ListenerId addListener(
    FutureOr<void> Function(nativeapi.WindowEvent) callback,
  ) {
    _listener = callback;
    return 1;
  }

  @override
  bool removeListener(nativeapi.ListenerId listenerId) {
    _listener = null;
    return true;
  }
}

/// A close request that records whether it was cancelled.
class FakeCloseRequest extends nativeapi.EventRequest {
  FakeCloseRequest() : super.borrowed(0);

  bool cancelled = false;

  @override
  bool cancel() => cancelled = true;
}
