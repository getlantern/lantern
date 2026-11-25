import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:lantern/core/desktop/app_window.dart';

part 'window_notifier.g.dart';

@Riverpod(keepAlive: true)
class WindowNotifier extends _$WindowNotifier {
  @override
  Future<void> build() async {}

  Future<void> open({bool focus = true}) async {
    AppWindow.instance.show(focus: focus);
    if (Platform.isMacOS) {
      AppWindow.instance.visibleInTaskbar = true;
    }
  }

  Future<void> close() async {
    AppWindow.instance.hide();
    if (Platform.isMacOS) {
      AppWindow.instance.visibleInTaskbar = false;
    }
    AppWindow.instance.destroy();
    await Future.microtask(() => exit(0));
  }
}
