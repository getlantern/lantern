import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';

enum _PlatformType {
  android,
  ios,
  windows,
  macos,
  linux,
}

@RoutePage(name: 'DownloadLinks')
class DownloadLinks extends StatelessWidget {
  const DownloadLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(title: 'download_links'.i18n, body: _buildBody(context));
  }

  Widget _buildBody(BuildContext buildContext) {
    final theme = Theme.of(buildContext).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: AppImage(
              path: AppImagePaths.globIllustration,
              type: AssetType.png,
              height: 180.h,
              width: 180.w,
            ),
          ),
          SizedBox(height: defaultSize),
          Card(
            child: AppTile(
              icon: AppImagePaths.lanternLogoRounded,
              trailing: AppImage(path: AppImagePaths.outsideBrowser),
              label: 'Lantern.io',
              onPressed: () {},
            ),
          ),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'Alternative Download Links',
              style: theme.labelLarge!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          SizedBox(height: 4.0),
          Card(
            child: Column(
              children: [
                AppTile.link(
                  url: AppUrls.lanternGithub,
                  icon: AppImagePaths.github,
                  label: 'Github Download Page',
                ),
                DividerSpace(),
                AppTile.link(
                  url: AppUrls.telegramBot,
                  icon: AppImagePaths.telegram,
                  label: 'Telegram Bot',
                ),
              ],
            ),
          ),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'If you encounter any issues accessing our website, you can download Lantern from the links above.',
              style: theme.bodyMedium!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          SizedBox(height: defaultSize),
          DividerSpace(),
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'Available on:',
              style: theme.labelLarge!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          SizedBox(height: 4.0),
          _availableRow(),
        ],
      ),
    );
  }

  Widget _availableRow() {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        runSpacing: 5,
        alignment: WrapAlignment.spaceEvenly,
        spacing: 5,
        children: [
          PlatformCard(
            imagePath: AppImagePaths.android,
            onPressed: () => onPlatformTap(_PlatformType.android),
          ),
          PlatformCard(
            imagePath: AppImagePaths.windows,
            onPressed: () => onPlatformTap(_PlatformType.windows),
          ),
          PlatformCard(
            imagePath: AppImagePaths.ios,
            onPressed: () => onPlatformTap(_PlatformType.ios),
          ),
          PlatformCard(
            imagePath: AppImagePaths.macos,
            onPressed: () => onPlatformTap(_PlatformType.macos),
          ),
          PlatformCard(
            imagePath: AppImagePaths.linux,
            onPressed: () => onPlatformTap(_PlatformType.linux),
          ),
        ],
      ),
    );
  }

  void onPlatformTap(_PlatformType platformType) {
    switch (platformType) {
      case _PlatformType.android:
        UrlUtils.openUrl(AppUrls.downloadAndroid);
        break;
      case _PlatformType.ios:
        UrlUtils.openUrl(AppUrls.downloadIos);
        break;
      case _PlatformType.windows:
        UrlUtils.openUrl(AppUrls.downloadWindows);
        break;
      case _PlatformType.macos:
        UrlUtils.openUrl(AppUrls.downloadMac);
        break;
      case _PlatformType.linux:
        UrlUtils.openUrl(AppUrls.downloadLinux);
        break;
    }
  }
}
