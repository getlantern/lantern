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
      (_) async {
        if (PlatformUtils.isDesktop) {
          windowManager.addListener(this);
          await windowManager.setPreventClose(true);
        }
      },
    );
    _setupProtocol();
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
