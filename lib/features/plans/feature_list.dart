import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/utils/screen_utils.dart';

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
            title: 'Select your server location'),
        _FeatureTile(
            image: AppImagePaths.blot,
            title: 'Faster speeds & unlimited bandwidth'),
        _FeatureTile(
            image: AppImagePaths.premium,
            title: 'Premium servers with less congestion'),
        _FeatureTile(
            image: AppImagePaths.eyeHide,
            title: 'Advanced anti-censorship technology'),
        _FeatureTile(
            image: AppImagePaths.roundCorrect,
            title: 'Exclusive access to new features'),
        _FeatureTile(
            image: AppImagePaths.connectDevice,
            title: 'Connect up to 5 devices'),
        _FeatureTile(
            image: AppImagePaths.adBlock, title: 'Built in ad blocking'),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String image;
  final String title;

  const _FeatureTile({super.key, required this.image, required this.title});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: 16, vertical: context.isSmallDevice ? 7 : 8),
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
