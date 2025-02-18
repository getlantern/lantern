import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/common.dart';

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
}

@RoutePage(name: 'Setting')
class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: CustomAppBar(title: 'Setting'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ListView(
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
                    onPressed: () =>
                        settingMenuTap(_SettingType.checkForUpdates),
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
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  AppTile(
                    label: 'Logout',
                    icon: AppImagePaths.signIn,
                    onPressed: () => settingMenuTap(_SettingType.logout),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void settingMenuTap(_SettingType menu) {
    switch (menu) {
      case _SettingType.signIn:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.splitTunneling:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.serverLocations:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.language:
        // TODO: Handle this case.
        throw UnimplementedError();
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
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.downloadLinks:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.checkForUpdates:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.account:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.vpnSetting:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.logout:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }
}
