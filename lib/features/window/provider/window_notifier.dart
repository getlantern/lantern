import 'dart:io';

import 'package:lantern/core/utils/platform_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/common/common.dart';

part 'window_notifier.g.dart';

@Riverpod(keepAlive: true)
class WindowNotifier extends _$WindowNotifier {
  bool _skipNextCloseConfirm = false;

  @override
  Future<void> build() async {
    if (!PlatformUtils.isDesktop) return;
    await windowManager.ensureInitialized();
    await windowManager.setSize(desktopWindowSize);
    windowManager.setResizable(false);
  }

  Future<void> open({bool focus = true}) async {
    await windowManager.show();
    if (focus) await windowManager.focus();
    if (Platform.isMacOS) {
      await windowManager.setSkipTaskbar(false);
    }
  }

  /// Hide the window + set skip taskbar on macOS for tray-minimize UX
  Future<void> hideToTray() async {
    await windowManager.hide();
    if (Platform.isMacOS) {
      await windowManager.setSkipTaskbar(true);
    }
  }

  /// Initiates a programmatic close from the system tray
  Future<void> close() async {
    _skipNextCloseConfirm = true;
    await windowManager.setPreventClose(false);
    await windowManager.close();
    Future.microtask(() => _skipNextCloseConfirm = false);
  }

  /// Called by WindowWrapper to determine if next close should skip
  /// confirmation
  bool consumeSkipNextCloseConfirm() {
    final skip = _skipNextCloseConfirm;
    _skipNextCloseConfirm = false;
    return skip;
  }
}
