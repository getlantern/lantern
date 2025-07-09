import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/features/window/provider/window_notifier.dart';
import 'package:tray_manager/tray_manager.dart';

class SystemTrayWrapper extends StatefulHookConsumerWidget {
  final Widget child;

  const SystemTrayWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<SystemTrayWrapper> createState() => _SystemTrayWrapperState();
}

class _SystemTrayWrapperState extends ConsumerState<SystemTrayWrapper>
    with TrayListener {
  @override
  void initState() {
    super.initState();
    if (!PlatformUtils.isDesktop) {
      return;
    }
    _initializeTray();
  }

  Future<void> _initializeTray() async {
    trayManager.addListener(this);
    await updateTrayMenu();
  }

  Future<void> updateTrayMenu({bool isConnected = false}) async {
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'status',
          disabled: true,
          label: isConnected ? 'status_on'.i18n : 'status_off'.i18n,
        ),
        MenuItem(
          key: 'status',
          label: isConnected ? 'disconnect'.i18n : 'connect'.i18n,
          onClick: (item) => {},
        ),
        MenuItem.separator(),
        MenuItem(
            key: 'show_window',
            label: 'show'.i18n,
            onClick: (item) {
              ref.read(windowNotifierProvider.notifier).open();
            }),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: 'exit'.i18n,
          onClick: (item) async {},
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
    trayManager.setIcon(_trayIconPath(isConnected),
        isTemplate: Platform.isMacOS);
  }

  String _trayIconPath(bool connected) {
    if (Platform.isWindows) {
      return connected
          ? AppImagePaths.lanternConnectedIco
          : AppImagePaths.lanternDisconnectedIco;
    } else if (Platform.isMacOS) {
      return connected
          ? AppImagePaths.lanternDarkConnected
          : AppImagePaths.lanternDarkDisconnected;
    }
    return connected
        ? AppImagePaths.lanternConnected
        : AppImagePaths.lanternDisconnected;
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  /// TrayListener methods
  @override
  Future<void> onTrayIconMouseDown() async {
    if (Platform.isMacOS) {
      await trayManager.popUpContextMenu();
    } else {
      ref.read(windowNotifierProvider.notifier).open();
    }
  }

  @override
  Future<void> onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }
}
