import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/notification_event.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/notification_service.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vpn_notifier.g.dart';

var isDisconnectingState = (status) =>
    status == VPNStatus.connecting || status == VPNStatus.disconnecting;

// This should be called only once
// when app is in memory after radiance will track it
bool isServerLocationSet = false;

@Riverpod(keepAlive: true)
class VpnNotifier extends _$VpnNotifier {
  @override
  VPNStatus build() {
    ref.read(lanternServiceProvider).isVPNConnected();
    ref.listen(
      vPNStatusNotifierProvider,
      (previous, next) {
        final previousStatus = previous?.value?.status;
        final nextStatus = next.value!.status;

        if (previous != null &&
            previous.value != null &&
            previousStatus != nextStatus) {
          if (previousStatus != VPNStatus.connecting &&
              nextStatus == VPNStatus.disconnected) {
            sl<NotificationService>().showNotification(
              NotificationEvent.vpnDisconnected.id,
              title: 'app_name'.i18n,
              body: 'vpn_disconnected'.i18n,
              delay: Duration(seconds: 1),
            );
          } else if (nextStatus == VPNStatus.connected) {
            sl<NotificationService>().showNotification(
              NotificationEvent.vpnConnected.id,
              title: 'app_name'.i18n,
              body: 'vpn_connected'.i18n,
              delay: Duration(seconds: 1),
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
    return state == VPNStatus.disconnected ? startVPN() : stopVPN();
  }

  /// Starts the VPN connection.
  /// If the server location is set to auto, it will connect to the best available server.
  /// If a specific server location is set, it will connect to that server
  /// valid server location types are: auto,lanternLocation,privateServer
  Future<Either<Failure, String>> startVPN() async {
    final serverLocation = sl<LocalStorageService>().getSavedServerLocations();
    if (serverLocation.serverLocation.toServerLocationType ==
        ServerLocationType.auto) {
      return ref.read(lanternServiceProvider).startVPN();
    } else {
      final location = serverLocation.serverLocation;
      final tag = serverLocation.serverName;
      return connectToServer(location, tag);
    }
  }

  /// Connects to a specific server location.
  /// it supports lantern locations and private servers.
  Future<Either<Failure, String>> connectToServer(
      String location, String tag) async {
    final result =
        await ref.read(lanternServiceProvider).connectToServer(location, tag);
    return result;
  }

  Future<Either<Failure, String>> stopVPN() async {
    final result = await ref.read(lanternServiceProvider).stopVPN();
    return result;
  }
}
