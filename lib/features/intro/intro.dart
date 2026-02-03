import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'Intro')
class Intro extends HookConsumerWidget {
  const Intro({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = TextTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.white,
        title: LanternLogo(),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(0),
          child: DividerSpace(padding: EdgeInsets.zero),
        ),
      ),
      body: FlutterCarousel(
        options: FlutterCarouselOptions(
          height: double.infinity,
          viewportFraction: 1.0,
          showIndicator: true,
          slideIndicator: CircularSlideIndicator(
              slideIndicatorOptions: SlideIndicatorOptions(
            indicatorRadius: 1,
            indicatorBorderWidth: 10.0,
            indicatorBorderColor: AppColors.blue6,
            padding: EdgeInsets.only(bottom: 30.0),
            alignment: Alignment.bottomCenter,
          )),
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
        ],
      ),
    );
  }
}
