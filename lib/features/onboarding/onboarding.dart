import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/info_row.dart';

import '../home/provider/app_setting_notifier.dart';
import '../home/provider/radiance_settings_providers.dart';

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

    Future<void> onboardingCompleted() async {
      await ref
          .read(radianceSettingsProvider.notifier)
          .setRoutingMode(selectedRouteMode.value);
      ref.read(appSettingProvider.notifier).setOnboardingCompleted(true);
      final shouldShowExtensionDialog =
          appSetting.showSplashScreen && PlatformUtils.isMacOS;
      appRouter.pop();
      if (shouldShowExtensionDialog) {
        appLogger.info("Showing System Extension Dialog");
        // Defer the push to the next frame to avoid calling setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appRouter.push(const MacOSExtensionDialog());
        });
        // User has seen dialog, do not show again
        appLogger.info("Setting showSplashScreen to false");
        ref.read(appSettingProvider.notifier).setSplashScreen(false);
        return;
      }
    }

    return Scaffold(
      key: const Key('onboarding.screen'),
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        backgroundColor: context.bgElevated,
        title: LanternLogo(color: context.textPrimary),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0),
          child: DividerSpace(padding: EdgeInsets.zero),
        ),
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
                              color: context.textSecondary),
                        ),
                        SizedBox(height: 16),
                        Text('lantern_pro_tagline'.i18n)
                      ],
                    ),
                    slide2(context),
                    if (!PlatformUtils.isIOS)
                      slide3(context, selectedRouteMode),
                  ],
                ),
              ),
              PrimaryButton(
                key: const Key('onboarding.primary'),
                label:
                    pageIndex.value == 0 ? 'get_started'.i18n : 'continue'.i18n,
                isTaller: true,
                onPressed: () {
                  if (PlatformUtils.isIOS && pageIndex.value == 1) {
                    onboardingCompleted();
                    return;
                  }
                  if (pageIndex.value == 2) {
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
                )
              },
              SizedBox(height: 28.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget slide2(BuildContext context) {
    final textTheme = TextTheme.of(context);
    return Column(
      children: <Widget>[
        SizedBox(height: 24.0),
        Text(
          'what_makes_lantern_different'.i18n,
          style: textTheme.headlineSmall!.copyWith(
            color: context.textSecondary,
          ),
        ),
        SizedBox(height: 8.0),
        Text(
          'built_for_privacy_speed_freedom'.i18n,
          style: textTheme.bodyLarge!.copyWith(
            color: context.textSecondary,
          ),
        ),
        SizedBox(height: 24.0),
        AppTile(
          icon: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: AppImage(
              path: AppImagePaths.smartRouteMode,
              useThemeColor: false,
            ),
          ),
          label: '',
          labelWidget: Text(
            'smart_routing_mode'.i18n,
            style: textTheme.titleMedium!.copyWith(
              color: context.textPrimary,
            ),
          ),
          subtitle: Text(
            'region_specific_routing_description'.i18n,
            style: textTheme.bodyMedium!.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
        SizedBox(height: 24.0),
        AppTile(
          icon: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: AppImage(
                path: AppImagePaths.advanceProtocol, useThemeColor: false),
          ),
          label: '',
          labelWidget: Text(
            'advanced_protocols'.i18n,
            style: textTheme.titleMedium!.copyWith(
              color: context.textPrimary,
            ),
          ),
          subtitle: Text(
            'advanced_protocols_description'.i18n,
            style: textTheme.bodyMedium!.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
        SizedBox(height: 24.0),
        AppTile(
          icon: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: AppImage(
                path: AppImagePaths.privateServerIntro, useThemeColor: false),
          ),
          label: '',
          labelWidget: Text(
            'private_servers'.i18n,
            style: textTheme.titleMedium!.copyWith(
              color: context.textPrimary,
            ),
          ),
          subtitle: Text(
            'private_servers_description'.i18n,
            style: textTheme.bodyMedium!.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
        SizedBox(height: 24.0),
        AppTile(
          icon: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child:
                AppImage(path: AppImagePaths.nonProfit, useThemeColor: false),
          ),
          label: '',
          labelWidget: Text(
            'nonprofit_mission'.i18n,
            style: textTheme.titleMedium!.copyWith(
              color: context.textPrimary,
            ),
          ),
          subtitle: Text(
            'built_by_nonprofit'.i18n,
            style: textTheme.bodyMedium!.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget slide3(
    BuildContext context,
    ValueNotifier<RoutingMode> selectedMode,
  ) {
    final textTheme = TextTheme.of(context);

    return Column(
      children: <Widget>[
        SizedBox(height: 24.0),
        Text(
          'choose_your_routing_mode'.i18n,
          style: textTheme.headlineSmall!.copyWith(
            color: context.textSecondary,
          ),
        ),
        SizedBox(height: 24.0),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => selectedMode.value = RoutingMode.smart,
          child: RouteModeContainer(
            mode: RoutingMode.smart,
            isSelected: selectedMode.value == RoutingMode.smart,
          ),
        ),
        SizedBox(height: 16.0),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => selectedMode.value = RoutingMode.full,
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
              AppRadioButton<bool>(
                groupValue: isSelected,
                value: true,
              ),
              SizedBox(width: 16.0),
              Text(
                title(),
                style: textTheme.titleMedium!.copyWith(
                  color: context.textPrimary,
                ),
              ),
              SizedBox(width: 8.0),
              Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: context.statusInfoBorder),
                    color: context.statusInfoBg,
                  ),
                  child: Text(
                    tags(),
                    style: textTheme.labelMedium!
                        .copyWith(color: context.statusInfoText),
                  ))
            ],
          ),
          SizedBox(height: 4.0),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(description(),
                style: textTheme.bodyMedium!
                    .copyWith(color: context.textSecondary)),
          )
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
