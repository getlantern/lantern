import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/info_row.dart';

import '../home/provider/app_setting_notifier.dart';

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
    final appSetting = ref.read(appSettingProvider);

    void onboardingCompleted() {
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
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        backgroundColor: AppColors.white,
        title: const LanternLogo(),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0),
          child: DividerSpace(padding: EdgeInsets.zero),
        ),
      ),
      body: Container(
        color: AppColors.white,
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
                        indicatorBackgroundColor: AppColors.gray3,
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
                        ),
                        SizedBox(height: 48),
                        Text(
                          'welcome_to_lantern'.i18n,
                          style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray8),
                        ),
                        SizedBox(height: 16),
                        Text('lantern_pro_tagline'.i18n)
                      ],
                    ),
                    slide2(context),
                    if (!PlatformUtils.isIOS) slide3(context),
                  ],
                ),
              ),
              PrimaryButton(
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
                  label: 'skip_connect_now'.i18n,
                  textColor: AppColors.gray9,
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
            color: AppColors.gray8,
          ),
        ),
        SizedBox(height: 8.0),
        Text(
          'built_for_privacy_speed_freedom'.i18n,
          style: textTheme.bodyLarge!.copyWith(
            color: AppColors.gray8,
          ),
        ),
        SizedBox(height: 24.0),
        AppTile(
          icon: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: AppImage(path: AppImagePaths.smartRouteMode),
          ),
          label: '',
          titleAlignment: ListTileTitleAlignment.top,
          labelWidget: Text(
            'smart_routing_mode'.i18n,
            style: textTheme.titleMedium!.copyWith(
              color: AppColors.black,
            ),
          ),
          subtitle: Text(
            'region_specific_routing_description'.i18n,
            style: textTheme.bodyMedium!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        SizedBox(height: 24.0),
        AppTile(
          icon: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: AppImage(path: AppImagePaths.advanceProtocol),
          ),
          label: '',
          titleAlignment: ListTileTitleAlignment.top,
          labelWidget: Text(
            'advanced_protocols'.i18n,
            style: textTheme.titleMedium!.copyWith(
              color: AppColors.black,
            ),
          ),
          subtitle: Text(
            'advanced_protocols_description'.i18n,
            style: textTheme.bodyMedium!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        SizedBox(height: 24.0),
        AppTile(
          icon: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: AppImage(path: AppImagePaths.privateServerIntro),
          ),
          label: '',
          titleAlignment: ListTileTitleAlignment.top,
          labelWidget: Text(
            'private_servers'.i18n,
            style: textTheme.titleMedium!.copyWith(
              color: AppColors.black,
            ),
          ),
          subtitle: Text(
            'private_servers_description'.i18n,
            style: textTheme.bodyMedium!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        SizedBox(height: 24.0),
        AppTile(
          icon: Padding(
            padding: const EdgeInsets.only(top: 5.0),
            child: AppImage(path: AppImagePaths.nonProfit),
          ),
          label: '',
          titleAlignment: ListTileTitleAlignment.top,
          labelWidget: Text(
            'nonprofit_mission'.i18n,
            style: textTheme.titleMedium!.copyWith(
              color: AppColors.black,
            ),
          ),
          subtitle: Text(
            'built_by_nonprofit'.i18n,
            style: textTheme.bodyMedium!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
      ],
    );
  }

  Widget slide3(BuildContext context) {
    final textTheme = TextTheme.of(context);
    final routeMode =
        ref.watch(appSettingProvider.select((value) => value.routingMode));
    useEffect(() {
      Future(() {
        final routeMode =
            ref.read(appSettingProvider.select((v) => v.routingMode));

        if (routeMode == RoutingMode.full) {
          ref
              .read(appSettingProvider.notifier)
              .setRoutingMode(RoutingMode.smart);
        }
      });

      return null;
    }, const []);

    Future<void> onRouteChange(RoutingMode mode) async {
      final result =
          await ref.read(appSettingProvider.notifier).setRoutingMode(mode);
      result.fold(
        (failure) {
          context.showSnackBar('failed_to_update_routing_mode'.i18n);
        },
        (_) {},
      );
    }

    return Column(
      children: <Widget>[
        SizedBox(height: 24.0),
        Text(
          'choose_your_routing_mode'.i18n,
          style: textTheme.headlineSmall!.copyWith(
            color: AppColors.gray8,
          ),
        ),
        SizedBox(height: 24.0),
        GestureDetector(
            onTap: () => onRouteChange(RoutingMode.smart),
            child: RouteModeContainer(
                mode: RoutingMode.smart,
                isSelected: routeMode == RoutingMode.smart)),
        SizedBox(height: 16.0),
        GestureDetector(
          onTap: () => onRouteChange(RoutingMode.full),
          child: RouteModeContainer(
              mode: RoutingMode.full,
              isSelected: routeMode == RoutingMode.full),
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
        color: isSelected ? AppColors.blue1 : AppColors.gray1,
        borderRadius: BorderRadius.circular(16.0),
        border: isSelected
            ? Border.all(color: AppColors.blue7, width: 3.0)
            : Border.all(color: AppColors.gray2, width: 1.0),
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
                  color: AppColors.black,
                ),
              ),
              SizedBox(width: 8.0),
              Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: AppColors.blue4),
                    color: AppColors.blue2,
                  ),
                  child: Text(
                    tags(),
                    style:
                        textTheme.labelMedium!.copyWith(color: AppColors.blue8),
                  ))
            ],
          ),
          SizedBox(height: 4.0),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(description(),
                style: textTheme.bodyMedium!.copyWith(color: AppColors.gray8)),
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
