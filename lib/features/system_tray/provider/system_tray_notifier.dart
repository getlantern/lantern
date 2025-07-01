import 'dart:io';

import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/window/provider/window_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../../core/common/common.dart';

part 'system_tray_notifier.g.dart';

@Riverpod(keepAlive: true)
class SystemTrayNotifier extends _$SystemTrayNotifier with TrayListener {
  late VPNStatus _currentStatus;

  @override
  Future<void> build() async {
    if (!PlatformUtils.isDesktop) return;
    _currentStatus = ref.read(vpnNotifierProvider);

    ref.listen<VPNStatus>(
      vpnNotifierProvider,
      (previous, next) {
        _currentStatus = next;
        // Refresh menu on change
        updateTrayMenu();
      },
    );

    trayManager.addListener(this);
    await updateTrayMenu();
  }

  bool get isConnected => _currentStatus == VPNStatus.connected;

  Future<void> toggleVPN() async {
    final notifier = ref.read(vpnNotifierProvider.notifier);
    if (_currentStatus == VPNStatus.connected) {
      await notifier.stopVPN();
    } else if (_currentStatus == VPNStatus.disconnected) {
      await notifier.startVPN();
    }
  }

  Future<void> updateTrayMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'status_label',
          disabled: true,
          label: _currentStatus == VPNStatus.connected
              ? 'status_on'.i18n
              : 'status_off'.i18n,
        ),
        MenuItem(
          key: 'toggle',
          label: _currentStatus == VPNStatus.connected
              ? 'disconnect'.i18n
              : 'connect'.i18n,
          disabled: _currentStatus == VPNStatus.connecting ||
              _currentStatus == VPNStatus.disconnecting,
          onClick: (_) => toggleVPN(),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'show_window',
          label: 'show'.i18n,
          onClick: (_) {
            ref.read(windowNotifierProvider.notifier).open();
          },
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: 'exit'.i18n,
          onClick: (_) => exit(0),
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

  void dispose() {
    trayManager.removeListener(this);
  }
}
