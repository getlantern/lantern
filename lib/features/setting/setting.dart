import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/widgets/base_screen.dart';

import '../language/language.dart' show showLanguageBottomSheet;

enum _SettingType {
  account,
  signIn,
  vpnSetting,
  splitTunneling,
  serverLocations,
  language,
  appearance,
  support,
  followUs,
  getPro,
  downloadLinks,
  checkForUpdates,
  logout,
  browserUnbounded,
}

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      title: 'setting'.i18n,
      body: ListView(
        children: <Widget>[
          ProButton(
            onPressed: () {},
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: AppTile(
              label: 'Account',
              icon: AppImagePaths.signIn,
              onPressed: () => settingMenuTap(_SettingType.account),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: AppTile(
              label: 'Sign In',
              icon: AppImagePaths.signIn,
              onPressed: () => settingMenuTap(_SettingType.signIn),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                AppTile(
                  label: 'VPN Setting',
                  icon: AppImagePaths.glob,
                  onPressed: () => settingMenuTap(_SettingType.vpnSetting),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: DividerSpace(),
                ),
                AppTile(
                  label: 'Language',
                  icon: AppImagePaths.translate,
                  trailing: Text(
                    'English',
                    style: textTheme.titleMedium!.copyWith(
                      color: AppColors.blue7,
                    ),
                  ),
                  onPressed: () => settingMenuTap(_SettingType.language),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: DividerSpace(),
                ),
                AppTile(
                  label: 'Check for updates',
                  icon: AppImagePaths.update,
                  onPressed: () => settingMenuTap(_SettingType.checkForUpdates),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                AppTile(
                  label: 'Support',
                  icon: AppImagePaths.support,
                  onPressed: () => settingMenuTap(_SettingType.support),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: DividerSpace(),
                ),
                AppTile(
                  label: 'Download Links',
                  icon: AppImagePaths.desktop,
                  onPressed: () => settingMenuTap(_SettingType.downloadLinks),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: DividerSpace(),
                ),
                AppTile(
                  label: 'Follow us',
                  icon: AppImagePaths.thumb,
                  onPressed: () => settingMenuTap(_SettingType.followUs),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: DividerSpace(),
                ),
                AppTile(
                  label: 'Get 30 days of Pro free',
                  icon: AppImagePaths.star,
                  onPressed: () => settingMenuTap(_SettingType.getPro),
                ),
              ],
            ),
          ),
          // const SizedBox(height: 16),
          // Card(
          //   margin: EdgeInsets.zero,
          //   child: Column(
          //     children: [
          //       AppTile(
          //         label: 'Logout',
          //         icon: AppImagePaths.signIn,
          //         onPressed: () => settingMenuTap(_SettingType.logout),
          //       ),
          //     ],
          //   ),
          // ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(
              left: 16,
            ),
            child: Text(
              'lantern_projects'.i18n,
              style: textTheme.labelLarge!.copyWith(
                color: AppColors.gray8,
              ),
            ),
          ),
          Card(
            child: AppTile(
              icon: AppImagePaths.lanternLogoRounded,
              trailing: AppAsset(path: AppImagePaths.outsideBrowser),
              subtitle: Text(
                'help_fight_global_internet_censorship'.i18n,
                style: textTheme.labelMedium!.copyWith(
                  color: AppColors.gray7,
                ),
              ),
              label: 'Unbounded',
              onPressed: () {},
            ),
          )
        ],
      ),
    );
  }

  void settingMenuTap(_SettingType menu) {
    switch (menu) {
      case _SettingType.signIn:
        break;
      case _SettingType.splitTunneling:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.serverLocations:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.language:
        if (PlatformUtils.isDesktop()) {
          LanguageRoute().go(context);
          return;
        }
        showLanguageBottomSheet(context);
        break;
      case _SettingType.appearance:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.support:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.followUs:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.getPro:
        InviteFriendsRoute().go(context);
        break;
      case _SettingType.downloadLinks:
        DownloadLinksRoute().go(context);
        break;
      case _SettingType.checkForUpdates:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.account:
        AccountRoute().go(context);
        break;
      case _SettingType.vpnSetting:
        VPNSettingRoute().go(context);
        break;
      case _SettingType.logout:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.browserUnbounded:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}
