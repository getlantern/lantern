import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'Onboarding')
class Onboarding extends HookConsumerWidget {
  Onboarding({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = TextTheme.of(context);
    final controller = useState(FlutterCarouselController());
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: LanternLogo(),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0),
          child: DividerSpace(padding: EdgeInsets.zero),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: FlutterCarousel(
          options: FlutterCarouselOptions(
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
                  path: AppImagePaths.appIcon,
                  type: AssetType.png,
                ),
                SizedBox(height: 48),
                Text(
                  'welcome_to_lantern'.i18n,
                  style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: AppColors.gray8),
                ),
                SizedBox(height: 16),
                Text('lantern_pro_tagline'.i18n)
              ],
            ),
            slide2(context),
            slide3(context),
          ],
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
            child: AppImage(path: AppImagePaths.smartRouteMode),
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
            child: AppImage(path: AppImagePaths.smartRouteMode),
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
            child: AppImage(path: AppImagePaths.smartRouteMode),
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
        routeModeContainer('smart_routing'.i18n,
            'smart_routing_description'.i18n, 'fastest'.i18n, true, context),
        SizedBox(height: 16.0),
        routeModeContainer(
            'full_tunnel'.i18n,
            'traditional_vpn_mode_description'.i18n,
            'traditional_vpn_mode'.i18n,
            false,
            context),
      ],
    );
  }

  Widget routeModeContainer(String title, String description, String tag,
      bool isSelected, RoutingMode mode, BuildContext context) {
    final textTheme = TextTheme.of(context);
    return GestureDetector(
      onTap: () {},
      child: AnimatedContainer(
        duration: Duration(milliseconds: 400),
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.blue1 : AppColors.gray2,
          borderRadius: BorderRadius.circular(16.0),
          border: isSelected
              ? Border.all(color: AppColors.blue7, width: 3.0)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: [
                AppRadioButton<RoutingMode>(
                  groupValue: isSelected ? mode : null,
                  value: mode,
                ),
                SizedBox(width: 16.0),
                Text(title),
                SizedBox(width: 8.0),
                Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.0, vertical: 3.0),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: AppColors.blue4)),
                    child: Text(
                      tag,
                      style: textTheme.labelMedium!
                          .copyWith(color: AppColors.blue8),
                    ))
              ],
            ),
            SizedBox(height: 4.0),
            Padding(
              padding: const EdgeInsets.only(left: 38),
              child: Text(
                description,
                style: textTheme.bodyMedium!.copyWith(color: AppColors.gray8),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> select(RoutingMode mode) async {
    final result =
    await ref.read(appSettingProvider.notifier).setRoutingMode(mode);
    result.fold(
          (failure) {
        context.showSnackBar('failed_to_update_routing_mode'.i18n);
      },
          (_) {},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) appRouter.pop();
    });
  }

}
