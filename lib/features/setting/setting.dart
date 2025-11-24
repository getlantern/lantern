import 'package:auto_route/auto_route.dart';
import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/localization/localization_constants.dart';
import 'package:lantern/core/models/mapper/user_mapper.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/setting/follow_us.dart'
    show showFollowUsBottomSheet;
import 'package:lantern/lantern/lantern_service_notifier.dart';

import '../../core/services/injection_container.dart';

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
class Setting extends StatefulHookConsumerWidget {
  const Setting({super.key});

  @override
  ConsumerState<Setting> createState() => _SettingState();
}

class _SettingState extends ConsumerState<Setting> {
  @override
  Widget build(BuildContext context) {
    final appSetting = ref.watch(appSettingProvider);
    final locale = appSetting.locale;
    final textTheme = Theme.of(context).textTheme;
    final isUserPro = ref.isUserPro;
    return BaseScreen(
      title: 'settings'.i18n,
      padded: false,
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: defaultSize),
        children: <Widget>[
          if (!isUserPro)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ProButton(
                onPressed: () {
                  appRouter.push(const Plans());
                },
              ),
            ),
          const SizedBox(height: defaultSize),
          if (isUserPro)
            AppCard(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              child: AppTile(
                label: 'account'.i18n,
                icon: AppImagePaths.accountSetting,
                onPressed: () => settingMenuTap(_SettingType.account),
              ),
            ),
          const SizedBox(height: defaultSize),
          if (!appSetting.userLoggedIn)
            AppCard(
              padding: EdgeInsets.zero,
              child: AppTile(
                label: 'sign_in'.i18n,
                icon: AppImagePaths.signIn,
                onPressed: () => settingMenuTap(_SettingType.signIn),
              ),
            ),
          const SizedBox(height: defaultSize),
          AppCard(
            padding: EdgeInsets.zero,
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
                    displayLanguage(locale),
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
                  onPressed: () async =>
                      await settingMenuTap(_SettingType.checkForUpdates),
                ),
              ],
            ),
          ),
          const SizedBox(height: defaultSize),
          AppCard(
            padding: EdgeInsets.zero,
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
          if (appSetting.userLoggedIn) ...{
            const SizedBox(height: defaultSize),
            AppCard(
              padding: EdgeInsets.zero,
              child: AppTile(
                label: 'logout'.i18n,
                icon: AppImagePaths.signIn,
                onPressed: () => settingMenuTap(_SettingType.logout),
              ),
            ),
          },
          const SizedBox(height: defaultSize),
          if (kDebugMode || AppBuildInfo.version.isNotEmpty) ...{
            AppCard(
              padding: EdgeInsets.zero,
              child: AppTile(
                label: 'developer_mode'.i18n,
                icon: Icon(Icons.developer_board),
                onPressed: () {
                  appRouter.push(const DeveloperMode());
                },
              ),
            ),
          },
          const SizedBox(height: defaultSize),
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
          const SizedBox(height: 4),
          Card(
            child: AppTile(
              minHeight: 72,
              icon: AppImagePaths.lanternLogoRounded,
              trailing: AppImage(path: AppImagePaths.outsideBrowser),
              label: 'unbounded'.i18n,
              subtitle: Text(
                'help_fight_global_internet_censorship'.i18n,
                style: textTheme.labelMedium!.copyWith(
                  color: AppColors.gray7,
                ),
              ),
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

  Future<void> settingMenuTap(_SettingType menu) async {
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
      case _SettingType.appearance:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.support:
        appRouter.push(Support());
      case _SettingType.followUs:
        if (PlatformUtils.isDesktop) {
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
        await checkForUpdates();
        break;
      case _SettingType.account:
        final localUser = sl<LocalStorageService>().getUser()!;
        final userSignedIn = ref.watch(appSettingProvider).userLoggedIn;
        if (localUser.legacyUserData.isPro() && !userSignedIn) {
          // this mean user has pro account but not signed in
          updateProAccountFlow();
          return;
        }
        appRouter.push(Account());
        break;
      case _SettingType.vpnSetting:
        appRouter.push(VPNSetting());
        break;
      case _SettingType.logout:
        logoutDialog();
        break;
      case _SettingType.browserUnbounded:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Future<void> checkForUpdates() async {
    try {
      autoUpdater.checkForUpdates();
    } catch (e) {
      appLogger.error('Error checking for updates: $e');
      AppDialog.errorDialog(
          context: context,
          title: 'error'.i18n,
          content: e.localizedDescription);
    }
  }

  void logoutDialog() {
    final theme = Theme.of(context).textTheme;
    AppDialog.customDialog(
      context: context,
      action: [
        AppTextButton(
          label: 'not_now'.i18n,
          textColor: AppColors.gray8,
          onPressed: () {
            context.maybePop();
          },
        ),
        AppTextButton(
          label: 'logout'.i18n,
          onPressed: () {
            onLogout();
            context.maybePop();
          },
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: defaultSize),
          Text(
            'logout'.i18n,
            style: theme.headlineSmall,
          ),
          SizedBox(height: defaultSize),
          Text(
            'logout_message'.i18n,
            style: theme.bodyMedium!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ],
      ),
    );
  }

  void updateProAccountFlow() {
    AppDialog.customDialog(
      context: context,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: 24.0),
          AppImage(path: AppImagePaths.personAdd),
          SizedBox(height: 16.0),
          Text(
            'update_pro_account'.i18n,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: defaultSize),
          Text(
            'update_pro_account_message'.i18n,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: AppColors.gray8,
                ),
          ),
        ],
      ),
      action: [
        AppTextButton(
          label: 'cancel'.i18n,
          textColor: AppColors.gray6,
          onPressed: () {
            appRouter.maybePop();
          },
        ),
        AppTextButton(
          label: 'add_email'.i18n,
          onPressed: () {
            appRouter.popAndPush(AddEmail(authFlow: AuthFlow.signUp));
          },
        ),
      ],
    );
  }

  Future<void> onLogout() async {
    context.showLoadingDialog();
    final appSetting = ref.read(appSettingProvider);
    final result =
        await ref.read(lanternServiceProvider).logout(appSetting.email);
    result.fold(
      (l) {
        context.hideLoadingDialog();
        appLogger.error('Logout error: ${l.localizedErrorMessage}');
      },
      (user) {
        context.hideLoadingDialog();
        appRouter.popUntilRoot();
        ref.read(homeProvider.notifier).clearLogoutData();
        ref.read(homeProvider.notifier).updateUserData(user);

        appLogger.info('Logout success: $user');
      },
    );
  }
}
