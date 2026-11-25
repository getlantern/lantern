import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/desktop/app_window.dart';
import 'package:lantern/features/window/provider/window_notifier.dart';
import 'package:lantern/features/window/windows_protocol_registry.dart';

class WindowWrapper extends StatefulHookConsumerWidget {
  final Widget child;

  const WindowWrapper({super.key, required this.child});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _WindowWrapperState();
}

class _WindowWrapperState extends ConsumerState<WindowWrapper> {
  @override
  Widget build(BuildContext context) {
    ref.watch(windowProvider);
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isDesktop) {
      AppWindow.instance.focused.addListener(_onWindowFocus);
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
    // screen — revealing on that signal would expose exactly the blank window
    // this change exists to prevent. When the frame never reaches the screen
    // this never completes, so nothing is revealed and the platform runner's
    // own first-frame gate is left to decide, which is what an unmodified
    // Flutter app does.
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    if (!mounted) return;

    // Showing comes first and is kept separate: close interception is the
    // nice-to-have, the window is not. Arming it first meant a failure there
    // skipped the reveal entirely and left the app running with nothing on
    // screen — worse than the blank window this is all about.
    try {
      if (!AppWindow.instance.show()) {
        appLogger.warning('No window to reveal after first frame');
      }
    } catch (e, st) {
      appLogger.error('Failed to reveal window after first frame', e, st);
      return;
    }

    // From here the close button hides to the tray; AppWindow handles it.
    AppWindow.instance.preventClose = true;
  }

  @override
  void dispose() {
    if (PlatformUtils.isDesktop) {
      AppWindow.instance.focused.removeListener(_onWindowFocus);
    }
    super.dispose();
  }

  void _setupProtocol() {
    if (Platform.isWindows) {
      ProtocolRegistrar.instance.register('lantern');
      ProtocolRegistrar.instance.register('Lantern');
    }
  }

  void _onWindowFocus() {
    if (mounted) setState(() {});
  }
}
