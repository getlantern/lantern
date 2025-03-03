import 'dart:io';

import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/services/native_bridge.dart';

class VPNSwitch extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ffiClient = ref.read(ffiClientProvider);
    final NativeBridge _nativeBridge = NativeBridge();
    final _vpnStatus = useState<VPNStatus>(VPNStatus.disconnected);
    final _loading = useState<bool>(false);

    Future<void> _connectVPN() async {
      _loading.value = true;
      if (Platform.isIOS) {
        await _nativeBridge.startVPN();
      } else {
        ffiClient.startVPN();
      }
      await Future.delayed(const Duration(seconds: 1));
      _vpnStatus.value = VPNStatus.connected;
      _loading.value = false;
    }

    Future<void> _disconnectVPN() async {
      if (Platform.isIOS) {
        await _nativeBridge.stopVPN();
      } else {
        ffiClient.stopVPN();
      }
      _vpnStatus.value = VPNStatus.disconnected;
      _loading.value = false;
    }

    Future<void> onVPNStateChange(VPNStatus value) async {
      if (value case VPNStatus.connected) {
        await _connectVPN();
      } else if (value case VPNStatus.disconnected) {
        await _disconnectVPN();
      }
    }

    return AnimatedToggleSwitch<VPNStatus>.dual(
      current: _vpnStatus.value,
      first: VPNStatus.disconnected,
      second: VPNStatus.connected,
      spacing: 15.h,
      height: PlatformUtils.isDesktop() ? 70.h : 60.h,
      indicatorSize: Size(60, 60),
      loading: _loading.value,
      borderWidth: 5,
      style: ToggleStyle(
        indicatorColor: AppColors.gray2,
        backgroundColor: _vpnStatus == VPNStatus.connected
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
