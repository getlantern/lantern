import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';

class VPNSwitch extends StatefulWidget {
  const VPNSwitch({super.key});

  @override
  State<VPNSwitch> createState() => _VPNSwitchState();
}

class _VPNSwitchState extends State<VPNSwitch> {
  VPNStatus _vpnStatus = VPNStatus.disconnected;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedToggleSwitch<VPNStatus>.dual(
      current: _vpnStatus,
      first: VPNStatus.disconnected,
      second: VPNStatus.connected,
      spacing: 15.h,
      height: PlatformUtils.isDesktop() ? 70.h : 60.h,
      indicatorSize: Size(60, 60),
      loading: _loading,
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

  Future<void> onVPNStateChange(VPNStatus value) async {
    if (value case VPNStatus.connected) {
      _connectVPN();
    } else if (value case VPNStatus.disconnected) {
      _disconnectVPN();
    }
  }

  Future<void> _connectVPN() async {
    setState(() {
      _loading = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _vpnStatus = VPNStatus.connected;
      _loading = false;
    });
  }

  void _disconnectVPN() {
    setState(() {
      _vpnStatus = VPNStatus.disconnected;
      _loading = false;
    });
  }
}
