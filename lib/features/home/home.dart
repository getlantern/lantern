import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/utils/pro_utils.dart';
import 'package:lantern/features/home/provider/app_event_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/home/vpn_tab.dart';
import 'package:lantern/features/share_my_connection/share_my_connection.dart';
import 'package:lantern/features/vpn/provider/available_servers_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';

import '../../core/common/common.dart';

/// Root tab shell hosting the VPN and Unbounded tabs. Tab strip lives in
/// the AppBar so the chrome (Lantern logo + settings menu + account
/// actions) is shared across tabs and lines up with the Figma spec at
/// figma.com/design/hNlyYToB5TnX9SDBFDYJTq?node-id=2403-19287.
///
/// Tab labels carry a small dot indicator that turns green when the
/// matching feature is active (VPN: connected; Unbounded: peer share
/// on) and grey otherwise — also per spec.
@RoutePage(name: 'Home')
class Home extends HookConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabController = useTabController(initialLength: 2);
    final isUserPro = ref.watch(isUserProProvider);
    final userLoggedIn = ref.watch(
      appSettingProvider.select((s) => s.userLoggedIn),
    );
    final unboundedHidden = ref.watch(
      appSettingProvider.select((s) => s.unboundedHidden),
    );
    final featureFlag = ref.watch(featureFlagProvider);
    final vpnStatus = ref.watch(vpnProvider);
    final shareActive = ref.watch(shareProvider.select((s) => s.active));

    // First-frame side effects: kick off server fetch, gate onboarding,
    // macOS sysext dialog. Lifted unchanged from the old Home body so
    // app-launch behaviour stays the same after the tab refactor.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(availableServersProvider);
        final appSetting = ref.read(appSettingProvider);
        final appSettingNotifier = ref.read(appSettingProvider.notifier);
        if (!appSetting.onboardingCompleted) {
          appLogger.info(
            "User has not completed onboarding, navigating to Onboarding Screen",
          );
          appRouter.push(const Onboarding());
          return;
        }
        if (PlatformUtils.isMacOS) {
          appLogger.info(
            "App Setting - showSplashScreen: ${appSetting.showSplashScreen}",
          );
          if (appSetting.showSplashScreen) {
            appLogger.info("Showing System Extension Dialog");
            appRouter.push(const MacOSExtensionDialog());
            appLogger.info("Setting showSplashScreen to false");
            appSettingNotifier.setSplashScreen(false);
          }
        }
      });
      return null;
    }, const []);

    // Telemetry consent dialog — fires once per app session after the
    // first successful connection, gated on the metrics + traces
    // feature flags. Preserved from the old Home behaviour.
    useEffect(() {
      final appSetting = ref.read(appSettingProvider);
      if (appSetting.successfulConnection) {
        if (!appSetting.telemetryDialogDismissed &&
            (featureFlag.getBool(FeatureFlag.metrics) &&
                featureFlag.getBool(FeatureFlag.traces))) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showHelpLanternDialog(context, ref);
            ref.read(appSettingProvider.notifier).setShowTelemetryDialog(true);
          });
        }
      }
      return null;
    }, [featureFlag]);

    ref.read(appEventProvider);

    // Auto-enable Unbounded — gated on the "Auto-enable Unbounded"
    // toggle from Unbounded Settings (default ON). Fires from two
    // entry points so the spec's subtitle "Turn on automatically when
    // Lantern is open" is honoured whether the user connects the VPN
    // or not:
    //   1. App launch (useEffect below) — once on Home mount.
    //   2. VPN connect (ref.listen further down) — on every
    //      disconnected → connected transition, in case the toggle
    //      flipped on after launch or the user finally connects.
    // Both paths gate on (active || probing) to avoid re-triggering
    // while a Start is in flight, and skip the disclosure dialog
    // because the user has already opted in via settings.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final appSetting = ref.read(appSettingProvider);
        if (!appSetting.onboardingCompleted) return;
        if (!appSetting.unboundedAutoEnable) return;
        final share = ref.read(shareProvider);
        if (share.active || share.probing) return;
        ref.read(shareProvider.notifier).autoStart(ref);
      });
      return null;
    }, const []);

    ref.listen<VPNStatus>(vpnProvider, (prev, next) {
      if (prev == next) return;
      if (next != VPNStatus.connected) return;
      final autoEnable =
          ref.read(appSettingProvider).unboundedAutoEnable;
      if (!autoEnable) return;
      final share = ref.read(shareProvider);
      if (share.active || share.probing) return;
      // Defer to avoid mutating provider state inside the listen callback.
      Future.microtask(
        () => ref.read(shareProvider.notifier).autoStart(ref),
      );
    });

    return Scaffold(
      key: const Key('home.screen'),
      appBar: AppBar(
        title: LanternLogo(isPro: isUserPro, color: context.textPrimary),
        elevation: 5,
        leading: IconButton(
          onPressed: () => appRouter.push(Setting()),
          icon: const AppImage(path: AppImagePaths.menu),
        ),
        actions: [
          if (isUserPro)
            AppIconButton(
              path: AppImagePaths.accountCircle,
              onPressed: () async {
                final localUser = ref.read(homeProvider).value;
                final userSignedIn = ref.read(appSettingProvider).userLoggedIn;
                final email = localUser!.legacyUserData.email;
                final isPro = localUser.legacyUserData.isPro;
                if (isPro && !userSignedIn) {
                  await showProAccountFlowDialog(
                    context: context,
                    hasEmail: email.isNotEmpty,
                  );
                  return;
                }
                appRouter.push(Account());
              },
            )
          else if (!userLoggedIn)
            AppTextButton(
              label: 'sign_in'.i18n,
              onPressed: () => appRouter.push(const SignInEmail()),
            ),
        ],
        // Tab strip collapses when the user has hidden the Unbounded
        // tab in Unbounded Settings — with only one tab left, a strip
        // is just noise. Body falls back to VpnTab directly.
        bottom: unboundedHidden
            ? null
            : TabBar(
                controller: tabController,
                tabs: [
                  _TabLabel(
                      label: 'VPN',
                      active: vpnStatus == VPNStatus.connected),
                  _TabLabel(label: 'Unbounded', active: shareActive),
                ],
              ),
      ),
      body: unboundedHidden
          ? const VpnTab()
          : TabBarView(
              controller: tabController,
              children: const [
                VpnTab(),
                UnboundedTab(),
              ],
            ),
    );
  }
}

/// Tab label with the green/grey status dot from the Figma spec.
class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.green4 : context.textDisabled,
            ),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

void _showHelpLanternDialog(BuildContext context, WidgetRef ref) {
  final textTheme = Theme.of(context).textTheme;
  AppDialog.customDialog(
    context: context,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: 24),
        const AppImage(path: AppImagePaths.assessment),
        const SizedBox(height: 24),
        Text(
          'help_improve_lantern'.i18n,
          style: textTheme.headlineSmall!.copyWith(color: context.textPrimary),
        ),
        SizedBox(height: defaultSize),
        Text(
          'share_anonymous_usage_data'.i18n,
          style: textTheme.bodyMedium!.copyWith(color: context.textSecondary),
        ),
        SizedBox(height: defaultSize),
        Text(
          'data_we_collect'.i18n,
          style: AppTextStyles.bodyMediumBold.copyWith(
            color: context.textSecondary,
          ),
        ),
        SizedBox(height: defaultSize),
        Text(
          'you_can_change_anytime'.i18n,
          style: textTheme.bodyMedium!.copyWith(color: context.textSecondary),
        ),
      ],
    ),
    action: [
      AppTextButton(
        label: 'dont_allow'.i18n,
        textColor: context.textDisabled,
        onPressed: () {
          context.pop();
          ref.read(radianceSettingsProvider.notifier).setTelemetry(false);
        },
      ),
      AppTextButton(
        label: 'allow'.i18n,
        textColor: AppColors.blue6,
        onPressed: () {
          context.pop();
          ref.read(radianceSettingsProvider.notifier).setTelemetry(true);
        },
      ),
    ],
  );
}
