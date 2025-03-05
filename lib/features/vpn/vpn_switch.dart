import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/providers/ffi_provider.dart';
import 'package:lantern/core/services/logger_service.dart';

class VPNSwitch extends HookConsumerWidget {
  const VPNSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ffiClient = ref.read(ffiClientProvider);
    final _vpnStatus = useState<VPNStatus>(VPNStatus.disconnected);
    final _loading = useState<bool>(false);

    Future<void> _connectVPN() async {
      _loading.value = true;
      try {
        final errorMessage = ffiClient.startVPN();
        if (errorMessage != null) {
          context.showSnackBarError(errorMessage);
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
        _vpnStatus.value = VPNStatus.connected;
      } catch (e) {
        appLogger.error("Error connecting to vpn: $e");
      } finally {
        _loading.value = false;
      }
    }

    Future<void> _disconnectVPN() async {
      _loading.value = true;
      try {
        final errorMessage = ffiClient.stopVPN();
        if (errorMessage != null) {
          context.showSnackBarError(errorMessage);
          return;
        }
        _vpnStatus.value = VPNStatus.disconnected;
      } catch (e) {
        appLogger.error("Error disconnecting from vpn: $e");
      } finally {
        _loading.value = false;
      }
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
        backgroundColor: _vpnStatus.value == VPNStatus.connected
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
