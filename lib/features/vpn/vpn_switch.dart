import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';

class VPNSwitch extends HookConsumerWidget {
  const VPNSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(
      vPNStatusNotifierProvider,
      (previous, next) {
        if (next is AsyncData<LanternStatus> &&
            next.value.status == VPNStatus.error) {
          context.showSnackBarError('vpn_error'.i18n);
        }
      },
    );
    final _vpnStatus = ref.watch(vpnNotifierProvider);
    final isVPNOn = (_vpnStatus == VPNStatus.connected);
    return CustomAnimatedToggleSwitch<bool>(
      current: isVPNOn,
      allowUnlistedValues: false,
      values: [false, true],
      spacing: 10.h,
      loading: false,
      height: PlatformUtils.isDesktop() ? 70.h : 60.h,
      indicatorSize: Size(60, 60),
      iconBuilder: (context, local, global) {
        return SizedBox();
      },
      onTap: (newValue) => onVPNStateChange(ref, context),
      foregroundIndicatorBuilder: (context, global) {
        if (_vpnStatus == VPNStatus.connecting||_vpnStatus == VPNStatus.disconnecting) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(30.r),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                strokeWidth: 8.r,
                color: AppColors.gray1,
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: AppColors.gray1,
            borderRadius: BorderRadius.circular(30.r),
          ),
        );
      },
      wrapperBuilder: (context, global, child) {
        return Container(
          padding: EdgeInsets.all(5.r),
          decoration: BoxDecoration(
            color: _wrapperColor(_vpnStatus),
            borderRadius: BorderRadius.circular(50.r),
          ),
          child: child,
        );
      },
    );
  }

  Future<void> onVPNStateChange(WidgetRef ref, BuildContext context) async {
    final result =
        await ref.read(vpnNotifierProvider.notifier).onVPNStateChange(context);

    result.fold(
      (failure) => context.showSnackBarError(failure.localizedErrorMessage),
      (_) => null,
    );
  }

  Color _wrapperColor(VPNStatus vpnStatus) {
    appLogger.debug("VPN Status: $vpnStatus");
    switch (vpnStatus) {
      case VPNStatus.connected:
        return AppColors.blue4;
      case VPNStatus.connecting:
      case VPNStatus.disconnected:
        return AppColors.gray7;
      case VPNStatus.disconnecting:
        return AppColors.gray1;
      case VPNStatus.missingPermission:
        // TODO: Handle this case.
        throw UnimplementedError();
      case VPNStatus.error:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}
