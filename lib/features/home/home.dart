import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_text_styles.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/utils/pro_utils.dart';
import 'package:lantern/features/home/provider/app_event_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/home/vpn_tab.dart';
import 'package:lantern/features/setting/referral_reward_dialog.dart';
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
    // Congratulate the user once per converted referral, whenever fresh
    // user data lands (first load or later refreshes). listenManual (not
    // ref.listen) because the subscription must outlive a rebuild and is
    // torn down explicitly; the empty dep list keeps it to one
    // subscription for the widget's lifetime rather than one per build.
    useEffect(() {
      final sub = ref.listenManual(homeProvider, fireImmediately: true, (
        previous,
        next,
      ) {
        final user = next.value;
        if (user == null) return;
        if (!ref.read(appSettingProvider).onboardingCompleted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          checkAndShowReferralReward(context, user);
        });
      });
      return sub.close;
    }, const []);

    final tabController = useTabController(initialLength: 2);
    // Tell the Unbounded globe whether its tab is on screen so it can mute
    // its ~60fps sphere re-projection while the user is on the VPN tab
    // (TabBarView keeps the off-screen tab mounted and ticking). The globe
    // lives in tab index 1, so it should animate whenever any part of it
    // is on screen — including mid-swipe. animation.value is the
    // fractional tab position (0.0 = VPN fully shown, 1.0 = Unbounded
    // fully shown), so > 0 means the Unbounded tab is at least partly
    // revealed. (indexIsChanging only covers tap/animateTo, not a finger
    // drag, so it would freeze the globe during a swipe in.)
    // The app bar shows the Unbounded wordmark instead of the Lantern one
    // while that tab is up, so the title has to track the swipe too.
    final onUnboundedTab = useState(false);
    useEffect(() {
      void sync() {
        final pos =
            tabController.animation?.value ?? tabController.index.toDouble();
        ref.read(unboundedTabVisibleProvider.notifier).set(pos > 0.0);
        // Halfway through the swipe, so the title swaps once rather than
        // flickering per frame.
        onUnboundedTab.value = pos >= 0.5;
      }

      tabController.addListener(sync);
      sync();
      return () => tabController.removeListener(sync);
    }, [tabController]);
    final isUserPro = ref.watch(isUserProProvider);
    final userLoggedIn = ref.watch(
      appSettingProvider.select((s) => s.userLoggedIn),
    );
    final unboundedHidden = ref.watch(
      appSettingProvider.select((s) => s.unboundedHidden),
    );
    final featureFlag = ref.watch(featureFlagProvider);
    // Server-side gate for the whole Unbounded UI surface. Censored
    // regions get the flag off, so the tab, strip, and any auto-enable
    // hook disappear. The user's own "Hide Unbounded tab" toggle still
    // wins on top of this for non-censored users who want it hidden.
    final unboundedAvailable = featureFlag.getBool(FeatureFlag.unbounded);
    final showUnboundedTab = unboundedAvailable && !unboundedHidden;
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
    // toggle from Unbounded Settings (default ON) AND the per-user
    // "Hide Unbounded" toggle. Hiding the tab is the opt-out: a user
    // who hid Unbounded should not see it silently auto-enable in
    // the background. Fires from two entry points so the spec's
    // subtitle "Turn on automatically when Lantern is open" is
    // honoured whether the user connects the VPN or not:
    //   1. App launch (useEffect below) — once on Home mount.
    //   2. VPN connect (ref.listen further down) — on every
    //      disconnected → connected transition, in case the toggle
    //      flipped on after launch or the user finally connects.
    // Both paths gate on (active || probing) to avoid re-triggering
    // while a Start is in flight, and skip the disclosure dialog
    // because the user has already opted in via settings.
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!unboundedAvailable) return;
        final appSetting = ref.read(appSettingProvider);
        if (appSetting.unboundedHidden) return;
        if (!appSetting.onboardingCompleted) return;
        if (!appSetting.unboundedAutoEnable) return;
        final share = ref.read(shareProvider);
        if (share.active || share.probing) return;
        ref.read(shareProvider.notifier).autoStart(ref);
      });
      return null;
    }, [unboundedAvailable]);

    ref.listen<VPNStatus>(vpnProvider, (prev, next) {
      if (prev == next) return;
      if (next != VPNStatus.connected) return;
      if (!unboundedAvailable) return;
      final appSetting = ref.read(appSettingProvider);
      if (appSetting.unboundedHidden) return;
      if (!appSetting.unboundedAutoEnable) return;
      final share = ref.read(shareProvider);
      if (share.active || share.probing) return;
      // Call autoStart synchronously — shareProvider is a different
      // provider than vpnProvider (the one we're listening to), so
      // mutating it inside this callback doesn't risk a re-entrancy
      // cycle. The previous Future.microtask defer was unsafe under
      // teardown: if Home unmounted between the listener firing and
      // the microtask running, the deferred ref.read would be on a
      // disposed scope.
      ref.read(shareProvider.notifier).autoStart(ref);
    });

    return Scaffold(
      key: const Key('home.screen'),
      appBar: AppBar(
        title: showUnboundedTab && onUnboundedTab.value
            ? Text(
                'unbounded'.i18n.toUpperCase(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
              )
            : LanternLogo(isPro: isUserPro, color: context.textPrimary),
        elevation: 5,
        leading: IconButton(
          key: const Key('home.menu_button'),
          onPressed: () {
            appRouter.push(Setting());
          },
          icon: const AppImage(path: AppImagePaths.menu),
        ),
        actions: [
          if (isUserPro)
            AppIconButton(
              path: AppImagePaths.accountCircle,
              onPressed: () async {
                final localUser = ref.read(homeProvider).value;
                final userSignedIn = ref.read(appSettingProvider).userLoggedIn;
                await openAccountOrProAccountSetup(
                  context: context,
                  user: localUser,
                  userLoggedIn: userSignedIn,
                );
              },
            )
          else if (!userLoggedIn)
            AppTextButton(
              label: 'sign_in'.i18n,
              onPressed: () => appRouter.push(const SignInEmail()),
            ),
        ],
        // Tab strip collapses when Unbounded is unavailable — either the
        // server flag is off (censored region) or the user hid the tab
        // in Unbounded Settings. With only one tab left, a strip is just
        // noise; body falls back to VpnTab directly.
        bottom: !showUnboundedTab
            ? null
            : TabBar(
                controller: tabController,
                // Pill-shaped selection rather than the Material underline,
                // per the Figma spec. indicatorPadding insets the fill so the
                // pill floats inside the tab instead of filling it edge to
                // edge; the strip carries no divider in the spec.
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.blue1,
                  borderRadius: BorderRadius.circular(24),
                ),
                indicatorPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                dividerColor: Colors.transparent,
                labelColor: context.textPrimary,
                unselectedLabelColor: context.textSecondary,
                tabs: [
                  _TabLabel(
                      label: 'vpn'.i18n,
                      iconPath: AppImagePaths.key,
                      active: vpnStatus == VPNStatus.connected),
                  _TabLabel(
                      label: 'unbounded'.i18n,
                      iconPath: AppImagePaths.lanternLogoRounded,
                      active: shareActive),
                ],
              ),
      ),
      body: !showUnboundedTab
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

/// Tab label with the leading feature icon and green/grey status dot from the
/// Figma spec. The dot reflects whether the feature is running, which is
/// independent of which tab is selected.
class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.iconPath,
    required this.active,
  });

  final String label;
  final String iconPath;
  final bool active;

  @override
  Widget build(BuildContext context) {
    // TabBar wraps each tab in a DefaultTextStyle carrying the resolved
    // selected/unselected label colour, so tinting the icon from it keeps the
    // two in step without plumbing the selected index down here.
    final labelColor = DefaultTextStyle.of(context).style.color;
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppImage(path: iconPath, width: 18, height: 18, color: labelColor),
          const SizedBox(width: 8),
          Text(label),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.green4 : context.textDisabled,
            ),
          ),
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
