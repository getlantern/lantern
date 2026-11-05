import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/models/available_servers.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/window/provider/window_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/common/common.dart';
import '../../macos_extension/provider/macos_extension_notifier.dart';
import '../../vpn/provider/server_location_notifier.dart';

part 'system_tray_notifier.g.dart';

/// What keeps the tray from connecting, shown as the "Unable to Connect" row.
enum _Blocker { macosExtension, vpnConflict, other }

/// A connect request the tray can repeat past the conflict check.
typedef _ConnectAttempt =
    Future<Either<Failure, String>> Function({bool skipConflictCheck});

@Riverpod(keepAlive: true)
class SystemTrayNotifier extends _$SystemTrayNotifier with TrayListener {
  VPNStatus _currentStatus = VPNStatus.disconnected;
  bool _isUserPro = false;
  bool _canSelectServer = false;
  List<Server> _locations = [];
  RoutingMode _currentRoutingMode = RoutingMode.full;
  ServerLocation? _serverLocation;
  MacOSExtensionState _extensionState = const MacOSExtensionState(
    SystemExtensionStatus.unknown,
  );
  // The last failed connect from the tray, or the conflict found when the
  // menu opened. Cleared once a connection gets going.
  Failure? _connectFailure;
  bool _unboundedAvailable = false;
  bool _unboundedHidden = false;
  ShareState _share = const ShareState();

  bool get isConnected => _currentStatus == VPNStatus.connected;

  bool get _isAutoLocation =>
      _serverLocation?.serverType.toServerLocationType ==
      ServerLocationType.auto;

  bool get _showActionMode => _unboundedAvailable && !_unboundedHidden;

  _Blocker? get _blocker {
    if (isConnected || _currentStatus == VPNStatus.connecting) return null;
    // Unknown is the state before the first status arrives, not a blocker.
    if (PlatformUtils.isMacOS &&
        _extensionState.status != SystemExtensionStatus.unknown &&
        !_extensionState.isReady) {
      return _Blocker.macosExtension;
    }
    final failure = _connectFailure;
    if (failure == null) return null;
    return failure is VpnConflictFailure
        ? _Blocker.vpnConflict
        : _Blocker.other;
  }

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
    _canSelectServer = ref.read(canSelectServerProvider);
    _currentRoutingMode = ref.read(radianceSettingsProvider).routingMode;
    _serverLocation = ref.read(serverLocationProvider);
    if (PlatformUtils.isMacOS) {
      _extensionState = ref.read(macosExtensionProvider);
    }
    _unboundedAvailable = ref
        .read(featureFlagProvider)
        .getBool(FeatureFlag.unbounded);
    _unboundedHidden = ref.read(appSettingProvider).unboundedHidden;
    _share = ref.read(shareProvider);
  }

  void _setupListeners() {
    _listenToVPNStatus();
    _listenToProStatus();
    _listenToAvailableServers();
    _listenToServerLocation();
    _listenToRoutingMode();
    _listenToMacOSExtension();
    _listenToActionMode();
  }

  void _listenToVPNStatus() {
    ref.listen<VPNStatus>(vpnProvider, (previous, next) async {
      _currentStatus = next;
      if (next == VPNStatus.connecting || next == VPNStatus.connected) {
        _connectFailure = null;
      }
      await updateTrayMenu();
    });
  }

  void _listenToProStatus() {
    ref.listen<bool>(isUserProProvider, (previous, next) async {
      _isUserPro = next;
      await updateTrayMenu();
    });
    ref.listen<bool>(canSelectServerProvider, (previous, next) async {
      _canSelectServer = next;
      await updateTrayMenu();
    });
  }

  void _listenToAvailableServers() {
    ref.listen<AsyncValue<AvailableServers>>(availableServersProvider, (
      previous,
      next,
    ) async {
      // One entry per country/city, matching the in-app server list; a city
      // with several assigned routes would otherwise appear once per route.
      _locations = next.value?.lanternServerLocations ?? [];
      await updateTrayMenu();
    });
  }

  void _listenToServerLocation() {
    ref.listen<ServerLocation>(serverLocationProvider, (previous, next) async {
      _serverLocation = next;
      await updateTrayMenu();
    });
  }

  void _listenToRoutingMode() {
    ref.listen<RadianceSettingsState>(radianceSettingsProvider, (
      previous,
      next,
    ) async {
      if (next.routingMode != _currentRoutingMode) {
        _currentRoutingMode = next.routingMode;
        await updateTrayMenu();
      }
    });
  }

  void _listenToMacOSExtension() {
    if (!PlatformUtils.isMacOS) return;
    ref.listen<MacOSExtensionState>(macosExtensionProvider, (
      previous,
      next,
    ) async {
      _extensionState = next;
      await updateTrayMenu();
    });
  }

  void _listenToActionMode() {
    ref.listen<bool>(
      featureFlagProvider.select((f) => f.getBool(FeatureFlag.unbounded)),
      (previous, next) async {
        _unboundedAvailable = next;
        await updateTrayMenu();
      },
    );
    ref.listen<bool>(appSettingProvider.select((s) => s.unboundedHidden), (
      previous,
      next,
    ) async {
      _unboundedHidden = next;
      await updateTrayMenu();
    });
    // Only the fields the menu shows; peer snapshots change the rest often.
    ref.listen<(bool, bool, int)>(
      shareProvider.select((s) => (s.active, s.probing, s.activeCount)),
      (previous, next) async {
        _share = ref.read(shareProvider);
        await updateTrayMenu();
      },
    );
  }

  Future<void> toggleVPN() async {
    final notifier = ref.read(vpnProvider.notifier);
    if (_currentStatus == VPNStatus.connected) {
      await notifier.stopVPN(userInitiated: true);
    } else if (_currentStatus == VPNStatus.disconnected) {
      if (!_checkMacOSExtension()) return;
      await _connect(
        ({skipConflictCheck = false}) =>
            notifier.startVPN(skipConflictCheck: skipConflictCheck),
      );
    }
  }

  /// Handle location selection from tray menu
  Future<void> _onLocationSelected(Server server) async {
    if (!_checkMacOSExtension()) return;

    await _connect(({skipConflictCheck = false}) async {
      final result = await ref
          .read(vpnProvider.notifier)
          .connectToServer(
            ServerLocationType.lanternLocation,
            server.tag,
            skipConflictCheck: skipConflictCheck,
          );
      if (result.isRight()) {
        appLogger.info(
          'Connecting to ${server.location.country} - ${server.location.city}',
        );
        _saveServerLocation(server);
      }
      return result;
    });
  }

  /// Handle smart location selection from tray menu
  Future<void> _onSmartLocationSelected() async {
    if (!_checkMacOSExtension()) return;

    ref
        .read(serverLocationProvider.notifier)
        .updateServerLocation(initialServerLocation());
    await _connect(
      ({skipConflictCheck = false}) => ref
          .read(vpnProvider.notifier)
          .startVPN(force: true, skipConflictCheck: skipConflictCheck),
    );
  }

  /// Runs a connect and surfaces its failure. Connect Anyway on a VPN
  /// conflict repeats the same request past the check, so a location picked
  /// from the tray is the one it connects to.
  Future<void> _connect(_ConnectAttempt attempt) async {
    await _handleConnectResult(
      await attempt(),
      connectAnyway: () => attempt(skipConflictCheck: true),
    );
  }

  /// Handle routing mode selection from tray menu
  Future<void> _onRoutingModeSelected(RoutingMode mode) async {
    await ref.read(radianceSettingsProvider.notifier).setRoutingMode(mode);
  }

  Future<void> _toggleActionMode() async {
    final notifier = ref.read(shareProvider.notifier);
    // Consent is a dialog in the app window, so bring the window up first.
    // Only that path needs the navigator; with consent acknowledged the
    // toggle runs even before the first route has built.
    if (!_share.active && !notifier.consentAcked) {
      await ref.read(windowProvider.notifier).open(focus: true);
    }
    await notifier.toggle(_appContext);
  }

  /// Keeps a failed connect as the alert row and raises it in the app, as
  /// the in-app switch would. A connect that got going clears the row.
  Future<void> _handleConnectResult(
    Either<Failure, String> result, {
    Future<Either<Failure, String>> Function()? connectAnyway,
  }) async {
    await result.fold(
      (failure) async {
        appLogger.error('Failed to connect from tray: ${failure.error}');
        _connectFailure = failure;
        await updateTrayMenu();
        await _showConnectFailure(failure, connectAnyway: connectAnyway);
      },
      (_) async {
        _connectFailure = null;
        await updateTrayMenu();
      },
    );
  }

  /// Opens the app on whatever blocks connecting.
  Future<void> _onBlockerSelected() async {
    switch (_blocker) {
      case _Blocker.macosExtension:
        _checkMacOSExtension();
      case _Blocker.vpnConflict || _Blocker.other:
        await _showConnectFailure(_connectFailure!);
      case null:
        return;
    }
  }

  Future<void> _showConnectFailure(
    Failure failure, {
    Future<Either<Failure, String>> Function()? connectAnyway,
  }) async {
    await ref.read(windowProvider.notifier).open(focus: true);
    final context = _appContext;
    if (context == null || !context.mounted) return;
    if (failure is VpnConflictFailure) {
      // The alert row has no request to repeat: it starts the saved location.
      final retry =
          connectAnyway ??
          () =>
              ref.read(vpnProvider.notifier).startVPN(skipConflictCheck: true);
      AppDialog.vpnConflictDialog(
        context: context,
        onConnectAnyway: () async {
          appRouter.maybePop();
          await _handleConnectResult(await retry());
        },
      );
      return;
    }
    AppDialog.errorDialog(
      context: context,
      title: 'unable_to_connect'.i18n,
      content: failure.localizedErrorMessage,
    );
  }

  /// The router's navigator, which the tray's dialogs show under. Null until
  /// the first route has built.
  BuildContext? get _appContext => appRouter.navigatorKey.currentContext;

  /// Re-checks for a conflicting VPN right before the menu shows, so the
  /// alert row reflects the other VPN's state now, not the last attempt.
  Future<void> _refreshVpnConflict() async {
    if (!PlatformUtils.isMacOS) return;
    if (_currentStatus != VPNStatus.disconnected) return;
    final conflict = await ref.read(lanternServiceProvider).checkVpnConflict();
    // A connect that started during the query already cleared the row.
    if (_currentStatus != VPNStatus.disconnected) return;
    if (conflict == _connectFailure is VpnConflictFailure) return;
    _connectFailure = conflict ? VpnConflictFailure() : null;
    await updateTrayMenu();
  }

  /// Returns true if OK to proceed, false if blocked by missing extension
  bool _checkMacOSExtension() {
    if (PlatformUtils.isMacOS) {
      final systemExtensionStatus = ref.read(macosExtensionProvider);
      if (!systemExtensionStatus.isReady) {
        windowManager.show();
        appRouter.push(const MacOSExtensionDialog());
        return false;
      }
    }
    return true;
  }

  void _saveServerLocation(Server server) {
    final serverLocation = ServerLocation.fromServer(server: server);
    ref
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
        final auto_ = loc.autoLocation;
        if (auto_ == null) return '';
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

  String get _helpingLabel => _share.activeCount == 1
      ? 'helping_one_person'.i18n
      : 'helping_people'.i18n.fill([_share.activeCount]);

  Future<void> updateTrayMenu() async {
    final locationDisplay = _currentLocationDisplay;
    final busy =
        _currentStatus == VPNStatus.connecting ||
        _currentStatus == VPNStatus.disconnecting;

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
        if (_blocker != null)
          MenuItem(
            key: 'unable_to_connect',
            label: '⚠ ${'unable_to_connect'.i18n}',
            onClick: (_) => _onBlockerSelected(),
          ),
        MenuItem.separator(),

        MenuItem(
          key: 'toggle',
          label: _currentStatus == VPNStatus.connected
              ? 'disconnect'.i18n
              : 'connect'.i18n,
          disabled: busy,
          onClick: (_) => toggleVPN(),
        ),

        if (_canSelectServer && _locations.isNotEmpty)
          MenuItem.submenu(
            key: 'select_location',
            label: 'select_location'.i18n,
            disabled: busy,
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
                ..._locations.map((server) {
                  final displayName = server.location.city.isNotEmpty
                      ? '${server.location.country} - ${server.location.city}'
                      : server.location.country;
                  return MenuItem(
                    key: 'location_${server.tag}',
                    label: displayName,
                    icon: AppImagePaths.safeFlagPath(
                      server.location.countryCode,
                    ),
                    onClick: (_) => _onLocationSelected(server),
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
        if (_showActionMode) ...[
          MenuItem(
            key: 'action_mode_toggle',
            label: _share.active
                ? 'disable_action_mode'.i18n
                : 'enable_action_mode'.i18n,
            disabled: _share.probing,
            onClick: (_) => _toggleActionMode(),
          ),
          if (_share.active)
            MenuItem(
              key: 'helping_count',
              disabled: true,
              label: _helpingLabel,
            ),
          MenuItem.separator(),
        ],
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
    trayManager.setIcon(_trayIconPath(), isTemplate: Platform.isMacOS);
    trayManager.setToolTip('app_name'.i18n);
  }

  String _trayIconPath() {
    final alert = _blocker != null;
    if (Platform.isWindows) {
      if (isConnected) return AppImagePaths.lanternConnectedIco;
      return alert
          ? AppImagePaths.lanternAlertIco
          : AppImagePaths.lanternDisconnectedIco;
    } else if (Platform.isMacOS) {
      if (isConnected) return AppImagePaths.lanternDarkConnected;
      return alert
          ? AppImagePaths.lanternDarkAlert
          : AppImagePaths.lanternDarkDisconnected;
    }
    if (isConnected) return AppImagePaths.lanternConnected;
    return alert
        ? AppImagePaths.lanternAlert
        : AppImagePaths.lanternDisconnected;
  }

  /// Tray Event Handlers
  @override
  Future<void> onTrayIconMouseDown() async {
    if (Platform.isMacOS) {
      await _refreshVpnConflict();
      await trayManager.popUpContextMenu();
    } else {
      ref.read(windowProvider.notifier).open();
    }
  }

  @override
  Future<void> onTrayIconRightMouseDown() async {
    await _refreshVpnConflict();
    await trayManager.popUpContextMenu();
  }
}

/// Converts a 2-letter ISO country code to a flag emoji
/// e.g. "US" → "🇺🇸", "GB" → "🇬🇧"
String _countryCodeToFlagEmoji(String countryCode) {
  final code = countryCode.toUpperCase();
  if (code.length != 2) return '';
  // Ensure both characters are ASCII letters A–Z before computing the emoji.
  final isAsciiLetters = code.codeUnits.every((c) => c >= 0x41 && c <= 0x5A);
  if (!isAsciiLetters) return '';
  return String.fromCharCodes(code.codeUnits.map((c) => c - 0x41 + 0x1F1E6));
}
