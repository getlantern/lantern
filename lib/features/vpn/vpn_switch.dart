import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';

class VPNSwitch extends HookConsumerWidget {
  const VPNSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<LanternStatus>>(
      vPNStatusProvider,
      (previous, next) {
        if (next is AsyncData<LanternStatus> &&
            next.value.status == VPNStatus.error) {
          context.showSnackBar(
              next.value.error ?? 'error_while_vpn_connection'.i18n);
        }
      },
    );
    final vpnStatus = ref.watch(vpnProvider);
    final isVPNOn = (vpnStatus == VPNStatus.connected);
    return CustomAnimatedToggleSwitch<bool>(
      current: isVPNOn,
      allowUnlistedValues: false,
      values: [false, true],
      spacing: 10.h,
      onChanged: (value) {
        appLogger.info('VPN Switch changed to: $value');
        onVPNStateChange(ref, context);
      },
      loading: false,
      height: PlatformUtils.isDesktop ? 70.h : 65.h,
      indicatorSize: Size(60.r, 60.r),
      iconBuilder: (context, local, global) {
        return SizedBox();
      },
      foregroundIndicatorBuilder: (context, global) {
        if (vpnStatus == VPNStatus.connecting ||
            vpnStatus == VPNStatus.disconnecting) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(30.r),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(
                strokeWidth: 8.r,
                color: context.actionToggleKnobBg,
              ),
            ),
          );
        }
        return GestureDetector(
          key: const Key('vpn.toggle'),
          onTap: () {
            appLogger.info('VPN Switch tapped');
            onVPNStateChange(ref, context);
          },
          child: Container(
            decoration: BoxDecoration(
              color: context.actionToggleKnobBg,
              borderRadius: BorderRadius.circular(30.r),
            ),
          ),
        );
      },
      wrapperBuilder: (context, global, child) {
        return Container(
          key: Key('vpn.switch.${vpnStatus.name}'),
          padding: EdgeInsets.all(5.r),
          decoration: BoxDecoration(
            color: _wrapperColor(vpnStatus, context),
            borderRadius: BorderRadius.circular(50.r),
          ),
          child: child,
        );
      },
    );
  }

  Future<void> onVPNStateChange(WidgetRef ref, BuildContext context) async {
    if (PlatformUtils.isMacOS) {
      final systemExtensionStatus = ref.read(macosExtensionProvider);
      if (!systemExtensionStatus.isReady) {
        appRouter.push(const MacOSExtensionDialog());
        return;
      }
    }

    final result =
        await ref.read(vpnProvider.notifier).onVPNStateChange(context);

    if (!context.mounted) return;
    result.fold(
      (failure) {
        if (failure is VpnConflictFailure) {
          AppDialog.vpnConflictDialog(
            context: context,
            onConnectAnyway: () async {
              appRouter.maybePop();
              final retryResult = await ref
                  .read(vpnProvider.notifier)
                  .startVPN(skipConflictCheck: true);
              if (!context.mounted) return;
              retryResult.fold(
                (failure) {
                  context.showSnackBar(failure.localizedErrorMessage);
                  appLogger.error(
                      "Error changing VPN state: ${failure.error}");
                },
                (_) => null,
              );
            },
          );
        } else {
          context.showSnackBar(failure.localizedErrorMessage);
          appLogger.error(
              "Error changing VPN state: ${failure.error}");
        }
      },
      (_) => null,
    );
  }

  Color _wrapperColor(VPNStatus vpnStatus, BuildContext context) {
    switch (vpnStatus) {
      case VPNStatus.connected:
        return context.actionToggleBrandActiveBg;
      case VPNStatus.connecting:
      case VPNStatus.disconnected:
        return context.actionToggleDisabledBg;
      case VPNStatus.disconnecting:
        return context.textTertiary;
      case VPNStatus.missingPermission:
        return context.textTertiary;
      case VPNStatus.error:
        return context.textTertiary;
    }
  }
}
