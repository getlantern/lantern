import 'dart:io';

import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/entity/app_setting_entity.dart';
import 'package:lantern/core/models/entity/server_location_entity.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
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
  RoutingMode _currentRoutingMode = RoutingMode.full;
  ServerLocationEntity? _serverLocation;

  bool get isConnected => _currentStatus == VPNStatus.connected;

  bool get _isAutoLocation =>
      _serverLocation?.serverType.toServerLocationType ==
      ServerLocationType.auto;

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
    _currentRoutingMode = ref.read(appSettingProvider).routingMode;
    _serverLocation = ref.read(serverLocationProvider);
  }

  void _setupListeners() {
    _listenToVPNStatus();
    _listenToProStatus();
    _listenToAvailableServers();
    _listenToServerLocation();
    _listenToRoutingMode();
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

  void _listenToServerLocation() {
    ref.listen<ServerLocationEntity>(
      serverLocationProvider,
      (previous, next) async {
        _serverLocation = next;
        await updateTrayMenu();
      },
    );
  }

  void _listenToRoutingMode() {
    ref.listen<AppSetting>(
      appSettingProvider,
      (previous, next) async {
        if (previous?.routingMode != next.routingMode) {
          _currentRoutingMode = next.routingMode;
          await updateTrayMenu();
        }
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
    if (!_checkMacOSExtension()) return;

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

  /// Handle smart location selection from tray menu
  Future<void> _onSmartLocationSelected() async {
    if (!_checkMacOSExtension()) return;

    await ref
        .read(serverLocationProvider.notifier)
        .updateServerLocation(initialServerLocation());
    await ref.read(vpnProvider.notifier).startVPN(force: true);
  }

  /// Handle routing mode selection from tray menu
  Future<void> _onRoutingModeSelected(RoutingMode mode) async {
    await ref.read(appSettingProvider.notifier).setRoutingMode(mode);
  }

  /// Returns true if OK to proceed, false if blocked by missing extension
  bool _checkMacOSExtension() {
    if (PlatformUtils.isMacOS) {
      final systemExtensionStatus = ref.read(macosExtensionProvider);
      if (systemExtensionStatus.status != SystemExtensionStatus.installed &&
          systemExtensionStatus.status != SystemExtensionStatus.activated) {
        windowManager.show();
        appRouter.push(const MacOSExtensionDialog());
        return false;
      }
    }
    return true;
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

  /// Build the current location display string (flag emoji + city)
  /// shown when connected
  String get _currentLocationDisplay {
    try {
      if (_serverLocation == null) return '';

      final loc = _serverLocation!;
      String countryCode = '';
      String displayName = '';

      if (loc.serverType.toServerLocationType == ServerLocationType.auto) {
        /// For auto location, we use the autoLocation info which contains the actual connected server details
        final auto_ = loc.autoLocation!;
        countryCode = auto_.countryCode;
        displayName = auto_.displayName;
      } else {
        countryCode = loc.countryCode;
        displayName = loc.displayName;
      }

      if (displayName.isEmpty) return '';

      final flag = _countryCodeToFlagEmoji(countryCode);
      return flag.isNotEmpty ? '$flag $displayName' : displayName;
    } catch (e) {
      appLogger.error('Error building location display', e);
      return '';
    }
  }

  Future<void> updateTrayMenu() async {
    final locationDisplay = _currentLocationDisplay;

    final menu = Menu(
      items: [
        MenuItem.separator(),
        // Status: Connected / Disconnected (greyed out, non-clickable)
        MenuItem(
          key: 'status_label',
          disabled: true,
          label: _currentStatus == VPNStatus.connected
              ? 'status_on'.i18n
              : 'status_off'.i18n,
        ),

        if (isConnected && locationDisplay.isNotEmpty)
          MenuItem(
            key: 'current_location',
            disabled: true,
            label: locationDisplay,
          ),
        MenuItem.separator(),

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
            disabled: _currentStatus == VPNStatus.connecting ||
                _currentStatus == VPNStatus.disconnecting,
            submenu: Menu(
              items: [
                // Smart Location as first option with checkmark
                MenuItem.checkbox(
                  key: 'smart_location',
                  label: 'smart_location'.i18n,
                  checked: _isAutoLocation,
                  onClick: (_) => _onSmartLocationSelected(),
                ),
                MenuItem.separator(),
                // Server list
                ..._locations.map((location) {
                  final displayName = location.city.isNotEmpty
                      ? '${location.country} - ${location.city}'
                      : location.country;
                  return MenuItem(
                    key: 'location_${location.tag}',
                    label: displayName,
                    icon: AppImagePaths.safeFlagPath(location.countryCode),
                    onClick: (_) => _onLocationSelected(location),
                  );
                }),
              ],
            ),
          ),
        MenuItem.submenu(
          key: 'routing_mode',
          label: 'routing_mode'.i18n,
          submenu: Menu(
            items: [
              MenuItem.checkbox(
                key: 'smart_routing',
                label: 'smart_routing'.i18n,
                checked: _currentRoutingMode == RoutingMode.smart,
                onClick: (_) => _onRoutingModeSelected(RoutingMode.smart),
              ),
              MenuItem.checkbox(
                key: 'full_tunnel',
                label: 'full_tunnel'.i18n,
                checked: _currentRoutingMode == RoutingMode.full,
                onClick: (_) => _onRoutingModeSelected(RoutingMode.full),
              ),
            ],
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

/// Converts a 2-letter ISO country code to a flag emoji
/// e.g. "US" → "🇺🇸", "GB" → "🇬🇧"
String _countryCodeToFlagEmoji(String countryCode) {
  final code = countryCode.toUpperCase();
  if (code.length != 2) return '';
  // Ensure both characters are ASCII letters A–Z before computing the emoji.
  final isAsciiLetters = code.codeUnits.every(
    (c) => c >= 0x41 && c <= 0x5A,
  );
  if (!isAsciiLetters) return '';
  return String.fromCharCodes(
    code.codeUnits.map((c) => c - 0x41 + 0x1F1E6),
  );
}
