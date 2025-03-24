import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/providers/native_bridge_provider.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vpn_notifier.g.dart';

@Riverpod()
class VpnNotifier extends _$VpnNotifier {
  @override
  VPNStatus build() {
    state = VPNStatus.disconnected;
    return state;
  }

  Future<Either<Failure, String>> onVPNStateChange() async {
    if (state == VPNStatus.connecting || state == VPNStatus.disconnecting) {
      return Right("");
    }
    return state == VPNStatus.disconnected ? _connectVPN() : stopVPN();
  }

  Future<Either<Failure, String>> _connectVPN() async {
    state = VPNStatus.connecting;
    final result = await ref.read(lanternServiceProvider).startVPN();
    result.fold(
      (failure) {
        state = VPNStatus.disconnected;
      },
      (success) {
        if (success.contains('VPN permission denied')) {
          state = VPNStatus.disconnected;
          return;
        }
        state = VPNStatus.connected;
      },
    );
    return result;

    // try {
    //   final result = await ref.read(lanternServiceProvider).startVPN();
    //
    //   await Future.delayed(const Duration(seconds: 1));
    //   state = VPNStatus.connected;
    //   return Right(unit);
    // } catch (e) {
    //   appLogger.error("Error connecting to VPN: $e");
    //   state = VPNStatus.disconnected;
    //   return Left(
    //       Failure(error: e.toString(), localizedErrorMessage: e.toString()));
    // }
  }

  Future<String?> _startVPN() async {
    if (PlatformUtils.isDesktop()) {
      final ffiClient = ref.read(ffiClientProvider).value;
      return ffiClient!.startVPN();
    } else if (Platform.isIOS) {
      final nativeBridge = ref.read(nativeBridgeProvider);
      return await nativeBridge?.startVPN();
    }
    throw UnsupportedError('VPN is not supported on this platform.');
  }

  Future<Either<Failure, String>> stopVPN() async {
    try {
      final error = await _stopVPN();
      if (error != null) {
        state = VPNStatus.connected;
        appLogger.error("Error stopping VPN: $error");
        return Left(Failure(error: error, localizedErrorMessage: error));
      }
      state = VPNStatus.disconnected;
      return Right("unit");
    } catch (e) {
      appLogger.error("Error stopping VPN: $e");
      return Left(
          Failure(error: e.toString(), localizedErrorMessage: e.toString()));
    }
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
