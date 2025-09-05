import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/window/provider/window_notifier.dart';
import 'package:lantern/features/window/windows_protocol_registry.dart';
import 'package:window_manager/window_manager.dart';

class WindowWrapper extends StatefulHookConsumerWidget {
  final Widget child;

  const WindowWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _WindowWrapperState();
}

class _WindowWrapperState extends ConsumerState<WindowWrapper>
    with WindowListener {
  @override
  Widget build(BuildContext context) {
    ref.watch(windowNotifierProvider);
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) {
        if (PlatformUtils.isDesktop) {
          windowManager.addListener(this);
          _setupDesktopWindow();
        }
      },
    );
    _setupProtocol();
  }

  Future<void> _setupDesktopWindow() async {
    await windowManager.setPreventClose(true);
    await windowManager.setResizable(false);
    if (Platform.isMacOS) {
      await windowManager.setTitle('');
      await windowManager.setTitleBarStyle(TitleBarStyle.normal,
          windowButtonVisibility: true);
    }
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void dispose() {
    if (PlatformUtils.isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  /// Register custom protocol for Windows
  /// See more: https://pub.dev/packages/windows_protocol_registrar
  void _setupProtocol() {
    if (Platform.isWindows) {
      ProtocolRegistrar.instance.register('lantern');
      ProtocolRegistrar.instance.register('Lantern');
    }
  }

  // WindowListener
  @override
  void onWindowClose() async {
    if (!context.mounted) {
      return;
    }
    if (!PlatformUtils.isDesktop) {
      return;
    }
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      // Instead of closing, just hide (minimize to dock)
      windowManager.hide();
    } else {
      windowManager.destroy();
    }
  }

  @override
  void onWindowFocus() {
    setState(() {});
  }
}
