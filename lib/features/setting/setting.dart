import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/localization/localization_constants.dart';
import 'package:lantern/features/language/language_notifier.dart';
import 'package:lantern/features/setting/follow_us.dart'
    show showFollowUsBottomSheet;

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

@RoutePage(name: 'Setting')
class Setting extends HookConsumerWidget {

  Setting({super.key});

  late BuildContext context;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    this.context = context;
    final locale = ref.read(languageNotifierProvider);
    final textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      title: 'settings'.i18n,
      padded: false,
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: defaultSize),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ProButton(
              onPressed: () {
                appRouter.push(const Plans());
              },
            ),
          ),
          // const SizedBox(height: 16),
          // Card(
          //   margin: EdgeInsets.zero,
          //   child: AppTile(
          //     label: 'account'.i18n,
          //     icon: AppImagePaths.signIn,
          //     onPressed: () => settingMenuTap(_SettingType.account),
          //   ),
          // ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: AppTile(
              label: 'sign_in'.i18n,
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
                  label: 'vpn_settings'.i18n,
                  icon: AppImagePaths.glob,
                  onPressed: () => settingMenuTap(_SettingType.vpnSetting),
                ),
                DividerSpace(),
                AppTile(
                  label: 'language'.i18n,
                  icon: AppImagePaths.translate,
                  trailing: Text(
                    displayLanguage(locale.toString()),
                    style: textTheme.titleMedium!.copyWith(
                      color: AppColors.blue7,
                    ),
                  ),
                  onPressed: () => settingMenuTap(_SettingType.language),
                ),
                DividerSpace(),
                AppTile(
                  label: 'check_for_updates'.i18n,
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
                  label: 'support'.i18n,
                  icon: AppImagePaths.support,
                  onPressed: () => settingMenuTap(_SettingType.support),
                ),
                DividerSpace(),
                AppTile(
                  label: 'download_links'.i18n,
                  icon: AppImagePaths.desktop,
                  onPressed: () => settingMenuTap(_SettingType.downloadLinks),
                ),
                DividerSpace(),
                AppTile(
                  label: 'follow_us'.i18n,
                  icon: AppImagePaths.thumb,
                  onPressed: () => settingMenuTap(_SettingType.followUs),
                ),
                DividerSpace(),
                AppTile(
                  label: 'get_30_days_of_pro_free'.i18n,
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
          //         label: 'logout'.i18n,
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
              trailing: AppImage(path: AppImagePaths.outsideBrowser),
              subtitle: Text(
                'help_fight_global_internet_censorship'.i18n,
                style: textTheme.labelMedium!.copyWith(
                  color: AppColors.gray7,
                ),
              ),
              label: 'unbounded'.i18n,
              onPressed: () {
                UrlUtils.openUrl(AppUrls.unbounded);
              },
            ),
          ),
          SizedBox(height: defaultSize),
        ],
      ),
    );
  }

  void settingMenuTap(_SettingType menu) {
    switch (menu) {
      case _SettingType.signIn:
        appRouter.push(const SignInEmail());
        break;
      case _SettingType.splitTunneling:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.serverLocations:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.language:
        appRouter.push(Language());
        return;

        break;
      case _SettingType.appearance:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.support:
        appRouter.push(Support());
      case _SettingType.followUs:
        if (PlatformUtils.isDesktop()) {
          appRouter.push(FollowUs());
          return;
        }
        showFollowUsBottomSheet(context: context);
        break;
      case _SettingType.getPro:
        appRouter.push(InviteFriends());
        break;
      case _SettingType.downloadLinks:
        appRouter.push(DownloadLinks());
        break;
      case _SettingType.checkForUpdates:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.account:
        appRouter.push(Account());
        break;
      case _SettingType.vpnSetting:
        appRouter.push(VPNSetting());
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
