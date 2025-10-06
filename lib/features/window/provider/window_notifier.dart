import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

part 'window_notifier.g.dart';

@Riverpod(keepAlive: true)
class WindowNotifier extends _$WindowNotifier {
  @override
  Future<void> build() async {}

  Future<void> open({bool focus = true}) async {
    await windowManager.show();
    if (focus) await windowManager.focus();
    if (Platform.isMacOS) {
      await windowManager.setSkipTaskbar(false);
    }
  }

  Future<void> close() async {
    await windowManager.hide();
    if (Platform.isMacOS) {
      await windowManager.setSkipTaskbar(true);
    }
    await windowManager.destroy();
    await Future.microtask(() => exit(0));
  }
}
