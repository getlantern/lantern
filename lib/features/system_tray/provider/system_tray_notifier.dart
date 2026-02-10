import 'dart:io';

import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/window/provider/window_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/common/common.dart';
import '../../../core/services/injection_container.dart';
import '../../macos_extension/provider/macos_extension_notifier.dart';
import '../../vpn/provider/server_location_notifier.dart';

part 'system_tray_notifier.g.dart';

@Riverpod(keepAlive: true)
class SystemTrayNotifier extends _$SystemTrayNotifier with TrayListener {
  VPNStatus _currentStatus = VPNStatus.disconnected;
  bool _isUserPro = false;
  List<Location_> _locations = [];

  bool get isConnected => _currentStatus == VPNStatus.connected;

  @override
  Future<void> build() async {
    if (!PlatformUtils.isDesktop) return;
    _currentStatus = ref.read(vpnProvider);
    _initializeState();
    _setupListeners();
    _setupTrayManager();
    await updateTrayMenu();
  }

  void _setupTrayManager() {
    trayManager.addListener(this);
    ref.onDispose(() => trayManager.removeListener(this));
  }

  void _initializeState() {
    _currentStatus = ref.read(vpnProvider);
    _isUserPro = ref.read(isUserProProvider);
  }

  void _setupListeners() {
    _listenToVPNStatus();
    _listenToProStatus();
    _listenToAvailableServers();
  }

  void _listenToVPNStatus() {
    ref.listen<VPNStatus>(
      vpnProvider,
      (previous, next) async {
        _currentStatus = next;
        await updateTrayMenu();
      },
    );
  }

  void _listenToProStatus() {
    ref.listen<bool>(
      isUserProProvider,
      (previous, next) async {
        _isUserPro = next;
        await updateTrayMenu();
      },
    );
  }

  void _listenToAvailableServers() {
    ref.listen<AsyncValue<AvailableServers>>(
      availableServersProvider,
      (previous, next) async {
        final data = next.value;
        _locations = data?.lantern.locations.values.toList() ?? [];
        _locations.sort((a, b) {
          final cmp = a.country.compareTo(b.country);
          if (cmp != 0) return cmp;
          return a.city.compareTo(b.city);
        });
        await updateTrayMenu();
      },
    );
  }

  Future<void> toggleVPN() async {
    final notifier = ref.read(vpnProvider.notifier);
    if (_currentStatus == VPNStatus.connected) {
      await notifier.stopVPN();
    } else if (_currentStatus == VPNStatus.disconnected) {
      await notifier.startVPN();
    }
  }

  /// Handle location selection from tray menu
  Future<void> _onLocationSelected(Location_ location) async {
    /// Check if extension is installed and up to date before connecting
    if (PlatformUtils.isMacOS) {
      final systemExtensionStatus = ref.read(macosExtensionProvider);
      if (systemExtensionStatus.status != SystemExtensionStatus.installed &&
          systemExtensionStatus.status != SystemExtensionStatus.activated) {
        windowManager.show();
        appRouter.push(const MacOSExtensionDialog());
        return;
      }
    }

    final result = await ref.read(vpnProvider.notifier).connectToServer(
          ServerLocationType.lanternLocation,
          location.tag,
        );
    result.fold(
      (failure) => appLogger
          .error('Failed to connect: ${failure.localizedErrorMessage}'),
      (success) {
        appLogger.info('Connecting to ${location.country} - ${location.city}');
        _saveServerLocation(location);
      },
    );
  }

  Future<void> _saveServerLocation(Location_ location) async {
    final savedServerLocation =
        sl<LocalStorageService>().getSavedServerLocations();
    final serverLocation = savedServerLocation.lanternLocation(
      server: location,
      autoSelect: false,
    );
    await ref
        .read(serverLocationProvider.notifier)
        .updateServerLocation(serverLocation);
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
        if (_isUserPro && _locations.isNotEmpty)
          MenuItem.submenu(
            key: 'select_location',
            label: 'select_location'.i18n,
            submenu: Menu(
              items: _locations.map((location) {
                final displayName = location.city.isNotEmpty
                    ? '${location.country} - ${location.city}'
                    : location.country;
                return MenuItem(
                  key: 'location_${location.tag}',
                  label: displayName,
                  icon: AppImagePaths.safeFlagPath(location.countryCode),
                  onClick: (_) => _onLocationSelected(location),
                );
              }).toList(),
            ),
          ),
        if (!_isUserPro)
          MenuItem(
            key: 'upgrade_to_pro',
            label: 'upgrade_to_pro'.i18n,
            onClick: (_) {
              ref.read(windowProvider.notifier).open(focus: true);
              appRouter.push(Plans());
            },
          ),
        MenuItem.separator(),
        MenuItem(
          key: 'join_server',
          label: 'join_server'.i18n,
          onClick: (_) {
            // Open Lantern and navigate to the join server page
            ref.read(windowProvider.notifier).open(focus: true);
            appRouter.push(JoinPrivateServer());
          },
        ),
        MenuItem(
          key: 'show_window',
          label: 'show'.i18n,
          onClick: (_) {
            ref.read(windowProvider.notifier).open(focus: true);
          },
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'quit',
          label: 'quit'.i18n,
          onClick: (_) async {
            await ref.read(vpnProvider.notifier).stopVPN();
            await trayManager.destroy();
            await ref.read(windowProvider.notifier).close();
          },
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
    trayManager.setIcon(_trayIconPath(isConnected),
        isTemplate: Platform.isMacOS);
    trayManager.setToolTip('app_name'.i18n);
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

  /// Tray Event Handlers
  @override
  Future<void> onTrayIconMouseDown() async {
    if (Platform.isMacOS) {
      await trayManager.popUpContextMenu();
    } else {
      ref.read(windowProvider.notifier).open();
    }
  }

  @override
  Future<void> onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }
}
