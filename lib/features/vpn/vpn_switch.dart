import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';

class VPNSwitch extends HookConsumerWidget {
  const VPNSwitch({super.key, this.focusNode, this.autofocusOnTv = true});

  /// The TV shell's node, so the shell can send focus here from the screen.
  final FocusNode? focusNode;

  /// False in the TV shell, which decides itself when the switch takes focus.
  final bool autofocusOnTv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<LanternStatus>>(vPNStatusProvider, (previous, next) {
      // The TV shell mounts one switch per screen in the stack, and the
      // messenger is app-wide: only the visible one reports.
      if (PlatformUtils.tvShellEnabled &&
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      if (next is AsyncData<LanternStatus> &&
          next.value.status == VPNStatus.error) {
        context.showSnackBar(
          next.value.error ?? 'error_while_vpn_connection'.i18n,
        );
      }
    });
    final vpnStatus = ref.watch(vpnProvider);
    final isVPNOn = (vpnStatus == VPNStatus.connected);
    final showFocus = useState(false);
    final ownFocusNode = useFocusNode(debugLabel: 'VPNSwitch');
    final focusNode = this.focusNode ?? ownFocusNode;
    // On TV the switch claims focus itself, and Home pushes routes (e.g.
    // onboarding) over it; while covered it must not hold focus, or the remote
    // would toggle it unseen. Elsewhere Flutter's route focus restore suffices.
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    useEffect(() {
      if (PlatformUtils.isTv && autofocusOnTv && isCurrent) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focusNode.context != null) focusNode.requestFocus();
        });
      }
      return null;
    }, [isCurrent]);
    // onSurface: primary matches the connected track in dark mode.
    final ring = Border.all(
      color: Theme.of(context).colorScheme.onSurface,
      width: 3,
    );
    final tvShell = PlatformUtils.tvShellEnabled;
    // The knob is a bare GestureDetector, so make the whole switch focusable
    // for D-pad and keyboard users (Android TV, desktop Tab).
    return FocusableActionDetector(
      focusNode: focusNode,
      enabled: !PlatformUtils.isTv || isCurrent,
      onShowFocusHighlight: (value) => showFocus.value = value,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            appLogger.info('VPN Switch activated');
            onVPNStateChange(ref, context);
            return null;
          },
        ),
      },
      // The TV shell draws the ring outside the switch, clear of the track.
      child: _tvRing(
        tvShell && showFocus.value ? ring : null,
        tvShell,
        CustomAnimatedToggleSwitch<bool>(
          current: isVPNOn,
          allowUnlistedValues: false,
          values: [false, true],
          spacing: 10.h,
          onChanged: (value) {
            appLogger.info('VPN Switch changed to: $value');
            onVPNStateChange(ref, context);
          },
          loading: false,
          // On TV the track is the knob plus the inset the wrapper's padding
          // gives it at the sides, above and below too.
          height: tvShell
              ? 80.r
              : PlatformUtils.isDesktop
              ? 70.h
              : 65.h,
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
              // The TV shell gives the knob the same inset all round.
              padding: EdgeInsets.all(tvShell ? 10.r : 5.r),
              decoration: BoxDecoration(
                color: _wrapperColor(vpnStatus, context),
                borderRadius: BorderRadius.circular(50.r),
                border: showFocus.value && !tvShell ? ring : null,
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }

  /// On TV, room for the focus ring around [child]; elsewhere [child] as is.
  Widget _tvRing(Border? ring, bool tvShell, Widget child) {
    if (!tvShell) return child;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: ring,
      ),
      child: child,
    );
  }

  Future<void> onVPNStateChange(WidgetRef ref, BuildContext context) async {
    if (PlatformUtils.isMacOS) {
      final systemExtensionStatus = ref.read(macosExtensionProvider);
      if (!systemExtensionStatus.isReady) {
        final value = await appRouter.push(const MacOSExtensionDialog());
        if (!context.mounted) return;
        appLogger.info(
          'Returned from MacOS Extension Dialog with value: $value',
        );
        if (value is bool && value) {
          appLogger.info(
            'Retrying VPN state change after MacOS Extension setup',
          );
          return onVPNStateChange(ref, context);
        }
        return;
      }
    }

    final result = await ref.read(vpnProvider.notifier).onVPNStateChange();

    if (!context.mounted) return;
    result.fold((failure) {
      if (failure is VpnConflictFailure) {
        AppDialog.vpnConflictDialog(
          context: context,
          onConnectAnyway: () async {
            appRouter.maybePop();
            final retryResult = await ref
                .read(vpnProvider.notifier)
                .startVPN(skipConflictCheck: true);
            if (!context.mounted) return;
            retryResult.fold((failure) {
              context.showSnackBar(failure.localizedErrorMessage);
              appLogger.error("Error changing VPN state: ${failure.error}");
            }, (_) => null);
          },
        );
      } else {
        context.showSnackBar(failure.localizedErrorMessage);
        appLogger.error("Error changing VPN state: ${failure.error}");
      }
    }, (_) => null);
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
