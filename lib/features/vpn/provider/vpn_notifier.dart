import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/notification_event.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/notification_service.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vpn_notifier.g.dart';

@Riverpod(keepAlive: true)
class VpnNotifier extends _$VpnNotifier {
  @override
  VPNStatus build() {
    ref.read(lanternServiceProvider).isVPNConnected();
    ref.listen(
      vPNStatusProvider,
      (previous, next) {
        final previousStatus = previous?.value?.status;
        final nextStatus = next.value!.status;

        if (previous != null &&
            previous.value != null &&
            previousStatus != nextStatus) {
          if (previousStatus != VPNStatus.connecting &&
              nextStatus == VPNStatus.disconnected) {
            sl<NotificationService>().showNotification(
              id: NotificationEvent.vpnDisconnected.id,
              title: 'app_name'.i18n,
              body: 'vpn_disconnected'.i18n,
            );
          } else if (nextStatus == VPNStatus.connected) {
            if (PlatformUtils.isMobile) {
              HapticFeedback.mediumImpact();
            }

            /// Mark successful connection in app settings
            ref.read(appSettingProvider.notifier).setSuccessfulConnection(true);

            // Server location is updated via the "server-location" push event
            // from the Go side (handled by AppEventNotifier), not by polling
            // getAutoServerLocation here. This avoids a race where the NE
            // reports "connected" before the Go tunnel is fully ready.

            sl<NotificationService>().showNotification(
              id: NotificationEvent.vpnConnected.id,
              title: 'app_name'.i18n,
              body: 'vpn_connected'.i18n,
            );
          }
        }
        state = nextStatus;
      },
    );
    return VPNStatus.disconnected;
  }

  Future<Either<Failure, String>> onVPNStateChange(BuildContext context) async {
    if (state == VPNStatus.connecting || state == VPNStatus.disconnecting) {
      return Right("");
    }
    appLogger.info("VPN State Change requested. Current state: $state");
    return state == VPNStatus.disconnected ? startVPN() : stopVPN();
  }

  /// Starts the VPN connection.
  /// force parameter, if true it will always connect to auto tag
  /// If the server location is set to auto, it will connect to the best available server.
  /// If a specific server location is set, it will connect to that server
  /// valid server location types are: auto,lanternLocation,privateServer

  Future<Either<Failure, String>> startVPN({bool force = false}) async {
    final lantern = ref.read(lanternServiceProvider);
    final serverLocation = ref.read(serverLocationProvider);

    final type = serverLocation.serverType.toServerLocationType;
    if (type == ServerLocationType.auto || force) {
      appLogger.debug(
          'Got server location with type auto or force is true, starting VPN with auto');
      return lantern.startVPN();
    }

    final tag = serverLocation.serverName;
    final tagAvailable = await lantern.isTagAvailable(tag);
    if (!tagAvailable) {
      appLogger.debug('Server tag "$tag" not available, falling back to auto VPN');
      return lantern.startVPN();
    }
    return connectToServer(type, tag);
  }

  /// Connects to a specific server location.
  /// it supports lantern locations and private servers.
  Future<Either<Failure, String>> connectToServer(
      ServerLocationType location, String tag) async {
    appLogger.debug("Connecting to server: $location with tag: $tag");
    final result = await ref
        .read(lanternServiceProvider)
        .connectToServer(location.name, tag);
    return result;
  }

  Future<Either<Failure, String>> stopVPN() async {
    final result = await ref.read(lanternServiceProvider).stopVPN();
    return result;
  }
}
