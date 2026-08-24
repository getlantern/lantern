import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/first_frame_watchdog.dart';
import 'package:lantern/features/window/provider/window_notifier.dart';
import 'package:lantern/features/window/windows_protocol_registry.dart';
import 'package:window_manager/window_manager.dart';

class WindowWrapper extends StatefulHookConsumerWidget {
  final Widget child;

  const WindowWrapper({super.key, required this.child});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _WindowWrapperState();
}

class _WindowWrapperState extends ConsumerState<WindowWrapper>
    with WindowListener {
  @override
  Widget build(BuildContext context) {
    ref.watch(windowProvider);
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    // Registered here rather than in a post-frame callback: initState runs
    // during the build phase, so the close handler exists even when the app
    // goes on to never render a frame. preventClose is armed only after a
    // frame has been built, so the two are never live without each other.
    if (PlatformUtils.isDesktop) {
      windowManager.addListener(this);
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_revealWindow()),
    );
    _setupProtocol();
  }

  /// Reveals the window once there is something in it to see, and only then
  /// turns the close button into minimise-to-tray. Before that there is nothing
  /// to restore from the tray, so closing should really close.
  Future<void> _revealWindow() async {
    if (!mounted || !PlatformUtils.isDesktop) return;

    // A built frame is not a presented one. addPostFrameCallback fires when the
    // framework has finished the frame, before the rasterizer has put it on
    // screen — revealing on that signal would expose exactly the blank,
    // uncloseable window this change exists to prevent. If the frame never
    // reaches the screen this never completes and FirstFrameWatchdog takes
    // over instead.
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    if (!mounted) return;

    // The watchdog gave up and revealed the window already, deliberately
    // closable. A frame arriving after that must not quietly turn the close
    // button back into minimise-to-tray.
    if (FirstFrameWatchdog.recoveredFromTimeout) return;

    try {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    } catch (e, st) {
      appLogger.error('Failed to reveal window after first frame', e, st);
    }
  }

  @override
  void dispose() {
    if (PlatformUtils.isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  void _setupProtocol() {
    if (Platform.isWindows) {
      ProtocolRegistrar.instance.register('lantern');
      ProtocolRegistrar.instance.register('Lantern');
    }
  }

  @override
  void onWindowClose() async {
    if (!context.mounted || !PlatformUtils.isDesktop) {
      return;
    }
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      // minimize-to-tray/dock
      windowManager.hide();
    } else {
      windowManager.destroy();
    }
  }

  @override
  void onWindowFocus() => setState(() {});
}
