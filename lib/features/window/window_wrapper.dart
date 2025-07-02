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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (PlatformUtils.isDesktop) {
        windowManager.addListener(this);
        _setupDesktopWindow();
      }
    });
    _setupProtocol();
  }

  Future<void> _setupDesktopWindow() async {
    await windowManager.setPreventClose(true);
    await windowManager.setResizable(false);
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

  void _setupProtocol() {
    if (Platform.isWindows) {
      ProtocolRegistrar.instance.register('lantern');
      ProtocolRegistrar.instance.register('Lantern');
    }
  }

  @override
  void onWindowClose() async {
    if (!context.mounted) {
      return;
    }

    final notifier = ref.read(windowNotifierProvider.notifier);
    if (notifier.skipNextCloseConfirm) {
      return;
    }

    if (Localizations.of<MaterialLocalizations>(
            context, MaterialLocalizations) ==
        null) {
      // Fallback: don't show dialog if localizations are unavailable
      await notifier.hideToTray();
      return;
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('confirm_close_window'.i18n),
        actions: [
          TextButton(
            child: Text('No'.i18n),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Yes'.i18n),
            onPressed: () async {
              await notifier.hideToTray();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  void onWindowFocus() {
    setState(() {});
  }
}
