import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../core/common/common.dart';

class FeatureList extends StatelessWidget {
  const FeatureList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FeatureTile(
            image: AppImagePaths.location,
            title: 'select_your_server_location'.i18n),
        _FeatureTile(
            image: AppImagePaths.blot,
            title: 'faster_speeds_unlimited_bandwidth'.i18n),
        _FeatureTile(
            image: AppImagePaths.premium,
            title: 'premium_servers_less_congestion'.i18n),
        _FeatureTile(
            image: AppImagePaths.eyeHide,
            title: 'advanced_anti_censorship'.i18n),
        _FeatureTile(
            image: AppImagePaths.connectDevice,
            title: 'connect_up_to_five_devices'.i18n),
        _FeatureTile(
            image: AppImagePaths.adBlock, title: 'built_in_ad_blocking'.i18n),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String image;
  final String title;

  const _FeatureTile({required this.image, required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: 16, vertical:8),
      child: Row(
        children: [
          AppImage(
            path: image,
            color: AppColors.blue10,
            height: 24,
          ),
          SizedBox(width: defaultSize),
          Expanded(
            child: AutoSizeText(
              title,
              minFontSize: 10,
              maxLines: 1,
              maxFontSize: 16,
              overflow: TextOverflow.ellipsis,
              style: textTheme,
            ),
          ),
        ],
      ),
    );
  }
}
