import 'dart:io';

import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/providers/native_bridge_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vpn_notifier.g.dart';

@Riverpod()
class VpnNotifier extends _$VpnNotifier {
  @override
  VPNStatus build() {
    state = VPNStatus.disconnected;
    return state;
  }

  Future<void> onVPNStateChange() async {
    switch (state) {
      case VPNStatus.connected:
        state = VPNStatus.disconnecting;
        stopVPN();
        state = VPNStatus.disconnected;
        break;
      case VPNStatus.disconnected:
        state = VPNStatus.connecting;
        await _connectVPN();
        state = VPNStatus.connected;
        break;
      case VPNStatus.connecting:
        state = VPNStatus.disconnected;
        break;
      case VPNStatus.disconnecting:
        state = VPNStatus.disconnected;
        break;
    }
  }

  Future<void> _connectVPN() async {
    if (PlatformUtils.isDesktop()) {
      try {
        final ffiClient = ref.read(ffiClientProvider).value;
        final error = ffiClient!.startVPN();
        if (error != null) {
          throw Exception();
        } else {
          await Future.delayed(const Duration(seconds: 1));
          state = VPNStatus.connected;
        }
      } catch (e) {
        appLogger.error("Error connecting to vpn: $e");
      }
      return;
    }

    if (Platform.isIOS && ref.read(nativeBridgeProvider) != null) {
      final error = await ref.read(nativeBridgeProvider)?.startVPN();
      if (error != null) {
        state = VPNStatus.disconnected;
      } else {
        await Future.delayed(const Duration(seconds: 1));
        state = VPNStatus.connected;
      }
    }
  }

  void stopVPN() async {
    if (PlatformUtils.isDesktop()) {
      final ffiClient = ref.read(ffiClientProvider).value;
      final error = ffiClient!.stopVPN();
      if (error != null) {
        appLogger.error("Error stopping vpn: $error");
      }
      return;
    }

    if (Platform.isIOS && ref.read(nativeBridgeProvider) != null) {
      final error = await ref.read(nativeBridgeProvider)?.stopVPN();
      if (error != null) {
        appLogger.error("Error stopping vpn: $error");
      }
    }
  }
}
