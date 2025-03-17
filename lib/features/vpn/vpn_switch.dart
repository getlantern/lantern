import 'dart:io';

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/providers/native_bridge_provider.dart';
import 'package:lantern/core/services/logger_service.dart';

class VPNSwitch extends HookConsumerWidget {
  const VPNSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ffiClient = ref.watch(ffiClientProvider).value;
    final nativeBridge = ref.read(nativeBridgeProvider);
    final vpnStatus = useState<VPNStatus>(VPNStatus.disconnected);
    final isLoading = useState<bool>(false);

    Future<void> toggleVPN(bool connect) async {
      isLoading.value = true;
      try {
        String? errorMessage;
        if (Platform.isIOS && nativeBridge != null) {
          errorMessage = connect
              ? await nativeBridge.startVPN()
              : await nativeBridge.stopVPN();
        } else {
          errorMessage = connect ? ffiClient?.startVPN() : ffiClient?.stopVPN();
        }
        if (errorMessage != null) {
          context.showSnackBarError(errorMessage);
          // on error, set status to disconnected if we were previously connected
          if (vpnStatus.value == VPNStatus.connected) {
            vpnStatus.value = VPNStatus.disconnected;
          }
        } else {
          await Future.delayed(const Duration(seconds: 1));
          vpnStatus.value =
              connect ? VPNStatus.connected : VPNStatus.disconnected;
        }
      } catch (e) {
        appLogger.error("Error connecting to vpn: $e");
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> onVPNStateChange(VPNStatus value) async {
      await toggleVPN(value == VPNStatus.connected);
    }

    return AnimatedToggleSwitch<VPNStatus>.dual(
      current: vpnStatus.value,
      first: VPNStatus.disconnected,
      second: VPNStatus.connected,
      spacing: 15.h,
      height: PlatformUtils.isDesktop() ? 70.h : 60.h,
      indicatorSize: Size(60, 60),
      loading: isLoading.value,
      borderWidth: 5,
      style: ToggleStyle(
        indicatorColor: AppColors.gray2,
        backgroundColor: vpnStatus.value == VPNStatus.connected
            ? AppColors.blue3
            : AppColors.gray4,
        borderColor: Colors.transparent,
      ),
      loadingIconBuilder: (context, global) {
        return CupertinoActivityIndicator(
          animating: true,
          color: AppColors.gray5,
          radius: 15.r,
        );
      },
      onChanged: onVPNStateChange,
    );
  }
}

// Extension for showing error SnackBars.
extension SnackBarExtensions on BuildContext {
  void showSnackBarError(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
