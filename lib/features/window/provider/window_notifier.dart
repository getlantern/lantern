import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/common/common.dart';

part 'window_notifier.g.dart';

@Riverpod(keepAlive: true)
class WindowNotifier extends _$WindowNotifier {
  @override
  Future<void> build() async {
    if (!PlatformUtils.isDesktop()) return;
    await windowManager.ensureInitialized();
    await windowManager.setSize(desktopWindowSize);
    windowManager.setResizable(false);
  }

  void open() async {
    await windowManager.show();
    await windowManager.focus();
  }
}
