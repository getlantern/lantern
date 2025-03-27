import 'dart:io';

import 'package:flutter/src/widgets/framework.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/providers/native_bridge_provider.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vpn_notifier.g.dart';

@Riverpod()
class VpnNotifier extends _$VpnNotifier {
  @override
  VPNStatus build() {
    state = VPNStatus.disconnected;
    ref.read(lanternServiceProvider).isVPNConnected();
    ref.listen(
      vPNStatusNotifierProvider,
      (previous, next) {
        state = next.value!.status;
      },
    );
    return state;
  }

  Future<Either<Failure, String>> onVPNStateChange(BuildContext context) async {
    if (state == VPNStatus.connecting || state == VPNStatus.disconnecting) {
      return Right("");
    }
    return state == VPNStatus.disconnected ? _connectVPN() : stopVPN();
  }

  Future<Either<Failure, String>> _connectVPN() async {
    final result = await ref.read(lanternServiceProvider).startVPN();
    // result.fold(
    //   (failure) {
    //     state = VPNStatus.disconnected;
    //   },
    //   (success) {
    //     if (success.contains('VPN permission denied')) {
    //       //soft error for permission denied
    //       state = VPNStatus.disconnected;
    //       return;
    //     }
    //     state = VPNStatus.connected;
    //   },
    // );
    return result;
  }

  Future<Either<Failure, String>> stopVPN() async {
    final result = await ref.read(lanternServiceProvider).stopVPN();
    result.fold(
      (failure) {
        state = VPNStatus.connected;
      },
      (success) {
        state = VPNStatus.disconnected;
      },
    );
    return result;
  }

  Future<String?> _stopVPN() async {
    if (PlatformUtils.isDesktop()) {
      final ffiClient = ref.read(ffiClientProvider).value;
      return ffiClient?.stopVPN();
    } else if (Platform.isIOS) {
      final nativeBridge = ref.read(nativeBridgeProvider);
      return await nativeBridge?.stopVPN();
    }
    throw UnsupportedError('VPN is not supported on this platform.');
  }
}
