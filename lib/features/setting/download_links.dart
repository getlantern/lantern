import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/base_screen.dart';

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
            child: AppAsset(
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
              trailing: AppAsset(path: AppImagePaths.outsideBrowser),
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
                AppTile(
                  icon: AppImagePaths.github,
                  trailing: AppAsset(path: AppImagePaths.outsideBrowser),
                  label: 'Github Download Page',
                  onPressed: () {},
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DividerSpace(),
                ),
                AppTile(
                  icon: AppImagePaths.telegram,
                  trailing: AppAsset(path: AppImagePaths.outsideBrowser),
                  label: 'Telegram Bote',
                  onPressed: () {},
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
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: AppAsset(path: AppImagePaths.android),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: AppAsset(path: AppImagePaths.windows),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: AppAsset(path: AppImagePaths.ios),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: AppAsset(path: AppImagePaths.macos),
            ),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: AppAsset(path: AppImagePaths.linux),
            ),
          ),
        ],
      ),
    );
  }
}
