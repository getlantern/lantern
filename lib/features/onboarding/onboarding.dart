import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
// The route of the same name comes from the router.
import 'package:lantern/features/macos_extension/macos_extension_dialog.dart'
    hide MacOSExtensionDialog;
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';

import '../helpers/provider/helpers_notifier.dart';
import '../home/provider/app_setting_notifier.dart';
import '../home/provider/radiance_settings_providers.dart';
import 'action_mode_page.dart';
import 'personal_proxies_intro.dart';

@RoutePage(name: 'Onboarding')
class Onboarding extends StatefulHookConsumerWidget {
  const Onboarding({super.key});

  @override
  ConsumerState<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends ConsumerState<Onboarding> {
  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    final controller = useState(FlutterCarouselController());
    final pageIndex = useState(0);
    final selectedRouteMode = useState(RoutingMode.smart);
    final appSetting = ref.read(appSettingProvider);
    // Once shown, the page stays for this run, so a flag that changes cannot
    // pull it out from under the user.
    final actionModeOffered = ref.watch(actionModeOfferedProvider);
    final showActionMode = useRef(false);
    if (actionModeOffered) showActionMode.value = true;
    final personalProxies = ref.watch(helperInvitesAvailableProvider);
    // The pages this run has put in front of the user, for the Personal
    // Proxies introduction: the row counts only if it was there when What
    // makes Lantern different (page 1) showed.
    final furthestPage = useRef(0);
    if (pageIndex.value > furthestPage.value) {
      furthestPage.value = pageIndex.value;
    }
    final personalProxiesSeen = useRef(false);
    if (personalProxies && pageIndex.value == 1) {
      personalProxiesSeen.value = true;
    }
    final actionModePage = PlatformUtils.isIOS ? 2 : 3;
    // On macOS the network extension is the flow's last step, with its own
    // dot, the first time the app runs. Decided once: the flag is cleared as
    // onboarding finishes.
    final extensionPage = useMemoized(
      () => PlatformUtils.isMacOS && appSetting.showSplashScreen,
    );
    final extensionState = extensionPage
        ? ref.watch(macosExtensionProvider)
        : null;
    final lastPage =
        (PlatformUtils.isIOS ? 1 : 2) +
        (showActionMode.value ? 1 : 0) +
        (extensionPage ? 1 : 0);
    final onExtensionPage = extensionPage && pageIndex.value == lastPage;

    Future<void> onboardingCompleted() async {
      await ref
          .read(radianceSettingsProvider.notifier)
          .setRoutingMode(selectedRouteMode.value);
      ref.read(appSettingProvider.notifier).setOnboardingCompleted(true);
      // A user who saw them here needs no introduction later. One who
      // skipped past them, or whose flags came too late, still gets it.
      final actionModeSeen =
          showActionMode.value && furthestPage.value >= actionModePage;
      if (actionModeSeen || personalProxiesSeen.value) {
        ref.read(appSettingProvider.notifier).setPersonalProxiesIntroSeen(true);
      }
      // Skipped before reaching the extension page: the dialog asks instead.
      final shouldShowExtensionDialog =
          extensionPage && furthestPage.value < lastPage;
      appRouter.pop();
      if (extensionPage) {
        // User has seen it, do not show again
        appLogger.info("Setting showSplashScreen to false");
        ref.read(appSettingProvider.notifier).setSplashScreen(false);
      }
      if (shouldShowExtensionDialog) {
        appLogger.info("Showing System Extension Dialog");
        // Defer the push to the next frame to avoid calling setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appRouter.push(const MacOSExtensionDialog());
        });
      }
    }

    return Scaffold(
      key: const Key('onboarding.screen'),
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        backgroundColor: context.bgElevated,
        title: LanternLogo(color: context.textPrimary),
        actions: [
          // The extension can be set up later, from the VPN switch.
          if (onExtensionPage)
            CloseButton(
              key: const Key('onboarding.close'),
              onPressed: onboardingCompleted,
            ),
        ],
      ),
      body: Container(
        color: context.bgElevated,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: FlutterCarousel(
                  options: FlutterCarouselOptions(
                    onPageChanged: (index, reason) {
                      pageIndex.value = index;
                    },
                    controller: controller.value,
                    height: double.infinity,
                    viewportFraction: 1.0,
                    showIndicator: true,
                    pageSnapping: true,
                    floatingIndicator: true,
                    slideIndicator: CircularSlideIndicator(
                      slideIndicatorOptions: SlideIndicatorOptions(
                        indicatorRadius: 5,
                        itemSpacing: 15,
                        indicatorBorderWidth: 0.0,
                        // The design's dots: blue/300 on gray/300, the same
                        // palette colors in both themes.
                        currentIndicatorColor: AppColors.blue3,
                        indicatorBackgroundColor: context.borderInput,
                        enableAnimation: true,
                        padding: EdgeInsets.only(bottom: 10.0),
                        alignment: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  items: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppImage(
                          path: AppImagePaths.appIconSVG,
                          useThemeColor: false,
                        ),
                        SizedBox(height: 48),
                        Text(
                          'welcome_to_lantern'.i18n,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'lantern_pro_tagline'.i18n,
                          style: textTheme.bodyLarge?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    OnboardingDifferentPage(
                      personalProxies: personalProxies,
                      actionMode: showActionMode.value,
                    ),
                    if (!PlatformUtils.isIOS)
                      slide3(context, selectedRouteMode),
                    if (showActionMode.value) const OnboardingActionModePage(),
                    if (extensionPage)
                      OnboardingExtensionPage(
                        state: extensionState!,
                        onReady: onboardingCompleted,
                      ),
                  ],
                ),
              ),
              PrimaryButton(
                key: const Key('onboarding.primary'),
                label: pageIndex.value == 0
                    ? 'get_started'.i18n
                    : onExtensionPage
                    ? macOSExtensionButtonLabel(extensionState!.status)
                    : 'continue'.i18n,
                isTaller: true,
                onPressed: () {
                  if (onExtensionPage) {
                    // Finishes once the extension reports ready.
                    installMacOSExtension(ref, context, extensionState!);
                    return;
                  }
                  if (pageIndex.value >= lastPage) {
                    onboardingCompleted();
                    return;
                  }
                  controller.value.nextPage();
                },
              ),
              if (pageIndex.value == 0) ...{
                SizedBox(height: 12.0),
                AppTextButton(
                  key: const Key('onboarding.skip'),
                  label: 'skip_connect_now'.i18n,
                  textColor: context.textPrimary,
                  onPressed: () {
                    onboardingCompleted();
                  },
                ),
              },
              SizedBox(height: 28.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget slide3(BuildContext context, ValueNotifier<RoutingMode> selectedMode) {
    final textTheme = TextTheme.of(context);

    return Column(
      children: <Widget>[
        SizedBox(height: 24.0),
        Text(
          'choose_your_routing_mode'.i18n,
          style: textTheme.headlineSmall!.copyWith(color: context.textPrimary),
        ),
        SizedBox(height: 24.0),
        AppFocusable(
          onActivate: () => selectedMode.value = RoutingMode.smart,
          borderRadius: BorderRadius.circular(16.0),
          child: RouteModeContainer(
            mode: RoutingMode.smart,
            isSelected: selectedMode.value == RoutingMode.smart,
          ),
        ),
        SizedBox(height: 16.0),
        AppFocusable(
          onActivate: () => selectedMode.value = RoutingMode.full,
          borderRadius: BorderRadius.circular(16.0),
          child: RouteModeContainer(
            mode: RoutingMode.full,
            isSelected: selectedMode.value == RoutingMode.full,
          ),
        ),
        Spacer(),
        InfoRow(
          minTileHeight: 35,
          text: 'change_anytime_in_routing_mode_settings'.i18n,
        ),
        SizedBox(height: 40),
      ],
    );
  }
}

/// Room left under a page's content for the carousel's floating dots.
const onboardingIndicatorSpace = 32.0;

/// Onboarding's "What makes Lantern different" page. [personalProxies] adds
/// the Personal Proxies row, where helper invites are offered (censored
/// regions).
class OnboardingDifferentPage extends StatelessWidget {
  const OnboardingDifferentPage({
    super.key,
    required this.personalProxies,
    this.actionMode = false,
  });

  final bool personalProxies;

  /// Whether Action Mode is offered. Its row shows only where Personal
  /// Proxies doesn't, which takes its place in censored regions.
  final bool actionMode;

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    // Scrolls rather than overflows on a short window, now that censored
    // regions get a fifth row.
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          SizedBox(height: 24.0),
          Text(
            'what_makes_lantern_different'.i18n,
            style: textTheme.headlineSmall!.copyWith(
              color: context.textPrimary,
            ),
          ),
          SizedBox(height: 8.0),
          Text(
            'built_for_privacy_speed_freedom'.i18n,
            style: textTheme.bodyLarge!.copyWith(color: context.textSecondary),
          ),
          SizedBox(height: 24.0),
          OnboardingFeatureRow(
            icon: AppImage(
              path: AppImagePaths.smartRouteMode,
              useThemeColor: false,
            ),
            title: 'smart_routing_mode'.i18n,
            description: 'region_specific_routing_description'.i18n,
          ),
          SizedBox(height: 24.0),
          OnboardingFeatureRow(
            icon: AppImage(
              path: AppImagePaths.advanceProtocol,
              useThemeColor: false,
            ),
            title: 'advanced_protocols'.i18n,
            description: 'advanced_protocols_description'.i18n,
          ),
          SizedBox(height: 24.0),
          OnboardingFeatureRow(
            icon: AppImage(
              path: AppImagePaths.privateServerIntro,
              useThemeColor: false,
            ),
            title: 'private_servers'.i18n,
            description: 'private_servers_description'.i18n,
          ),
          if (personalProxies) ...[
            SizedBox(height: 24.0),
            OnboardingFeatureRow(
              rowKey: const Key('onboarding.personal_proxies'),
              icon: OnboardingIconTile(path: AppImagePaths.personAdd),
              title: 'onboarding_personal_proxies'.i18n,
              description: 'onboarding_personal_proxies_description'.i18n,
              isNew: true,
            ),
          ] else if (actionMode) ...[
            SizedBox(height: 24.0),
            OnboardingFeatureRow(
              rowKey: const Key('onboarding.action_mode_row'),
              icon: OnboardingIconTile(path: AppImagePaths.unbounded),
              title: 'unbounded'.i18n,
              description: 'onboarding_action_mode_row_description'.i18n,
            ),
          ],
          SizedBox(height: 24.0),
          OnboardingFeatureRow(
            icon: AppImage(path: AppImagePaths.nonProfit, useThemeColor: false),
            title: 'nonprofit_mission'.i18n,
            description: 'built_by_nonprofit'.i18n,
          ),
          SizedBox(height: onboardingIndicatorSpace),
        ],
      ),
    );
  }
}

/// Onboarding's Network Extension page (macOS): the extension explainer,
/// whose button sits with the flow's other buttons. Onboarding finishes as
/// soon as the extension is installed and active.
class OnboardingExtensionPage extends StatelessWidget {
  const OnboardingExtensionPage({
    super.key,
    required this.state,
    required this.onReady,
  });

  final MacOSExtensionState state;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    return MacOSExtensionWatcher(
      key: const Key('onboarding.network_extension'),
      onReady: onReady,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            top: 24.0,
            bottom: onboardingIndicatorSpace,
          ),
          child: MacOSExtensionContent(state: state),
        ),
      ),
    );
  }
}

/// One of onboarding's feature rows: an icon level with the title, the
/// title with a New badge where [isNew], and a description under it.
class OnboardingFeatureRow extends StatelessWidget {
  const OnboardingFeatureRow({
    super.key,
    this.rowKey,
    required this.icon,
    required this.title,
    required this.description,
    this.isNew = false,
    this.contentPadding,
  });

  final Key? rowKey;
  final Widget icon;
  final String title;
  final String description;
  final bool isNew;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    final label = Text(
      title,
      style: textTheme.titleMedium!.copyWith(color: context.textPrimary),
    );
    return AppTile(
      tileKey: rowKey,
      // The icon's top sits level with the title, as designed.
      titleAlignment: ListTileTitleAlignment.top,
      contentPadding: contentPadding,
      icon: icon,
      label: '',
      labelWidget: isNew
          ? Row(
              children: [
                Flexible(child: label),
                const SizedBox(width: 8.0),
                const NewBadge(),
              ],
            )
          : label,
      subtitle: Text(
        description,
        style: textTheme.bodyMedium!.copyWith(color: context.textSecondary),
      ),
    );
  }
}

class RouteModeContainer extends StatelessWidget {
  final RoutingMode mode;
  final bool isSelected;

  const RouteModeContainer({
    super.key,
    required this.mode,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isSelected ? context.bgHover : context.bgElevated,
        borderRadius: BorderRadius.circular(16.0),
        border: isSelected
            ? Border.all(color: context.borderInputFocus, width: 3.0)
            : Border.all(color: context.borderDefault, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              AppRadioButton<bool>(groupValue: isSelected, value: true),
              SizedBox(width: 16.0),
              Text(
                title(),
                style: textTheme.titleMedium!.copyWith(
                  color: context.textPrimary,
                ),
              ),
              SizedBox(width: 8.0),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: context.statusInfoBorder),
                  color: context.statusInfoBg,
                ),
                child: Text(
                  tags(),
                  style: textTheme.labelMedium!.copyWith(
                    color: context.statusInfoText,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.0),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(
              description(),
              style: textTheme.bodyMedium!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String title() {
    if (mode == RoutingMode.smart) {
      return 'smart_routing'.i18n;
    } else {
      return 'full_tunnel'.i18n;
    }
  }

  String description() {
    if (mode == RoutingMode.smart) {
      return 'smart_routing_description'.i18n;
    } else {
      return 'traditional_vpn_mode_description'.i18n;
    }
  }

  String tags() {
    if (mode == RoutingMode.smart) {
      return 'fastest'.i18n;
    } else {
      return 'traditional_vpn_mode'.i18n;
    }
  }
}

/// "New", beside a feature onboarding introduces.
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('onboarding.new_badge'),
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: context.statusSuccessBorder),
        color: context.statusSuccessBg,
      ),
      child: Text(
        'onboarding_new_badge'.i18n,
        style: TextTheme.of(
          context,
        ).labelMedium!.copyWith(color: context.statusSuccessText),
      ),
    );
  }
}

/// The tile the older rows' icons have drawn in, around one of the app's
/// icons.
class OnboardingIconTile extends StatelessWidget {
  const OnboardingIconTile({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: context.bgHover,
        border: Border.all(color: context.statusInfoBorder),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: AppImage(
        path: path,
        width: 22,
        height: 22,
        color: context.statusInfoText,
      ),
    );
  }
}
