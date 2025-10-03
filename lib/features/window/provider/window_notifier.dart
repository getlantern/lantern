import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lantern/core/common/common.dart';

part 'window_notifier.g.dart';

@Riverpod(keepAlive: true)
class WindowNotifier extends _$WindowNotifier {
  @override
  Future<void> build() async {
    if (!PlatformUtils.isDesktop) return;

    await windowManager.ensureInitialized();

    final options = WindowOptions(
      size: initialWindowSize,
      minimumSize: lockWindowSize ? initialWindowSize : minimumWindowSize,
      center: true,
      titleBarStyle: TitleBarStyle.normal,
      skipTaskbar: false,
    );

    // Lock size (390x760)
    await windowManager.setResizable(!lockWindowSize);

    await windowManager.setPreventClose(true);

    if (Platform.isMacOS) {
      await windowManager.setTitle('');
      await windowManager.setTitleBarStyle(
        TitleBarStyle.normal,
        windowButtonVisibility: true,
      );
    }

    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
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
    await Future.microtask(() => exit(0));
  }
}
