import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/common/common.dart';

part 'window_notifier.g.dart';

@Riverpod(keepAlive: true)
class WindowNotifier extends _$WindowNotifier {
  @override
  Future<void> build() async {
    if (!PlatformUtils.isDesktop) return;
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      size: desktopWindowSize,
      skipTaskbar: false,
    );
    windowManager.setResizable(false);
    windowManager.waitUntilReadyToShow(
      windowOptions,
      () async {
        await windowManager.setSize(desktopWindowSize);
        windowManager.show();
        windowManager.focus();
      },
    );
  }

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
    exit(0);
  }
}
