import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_build_info.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/localization/localization_constants.dart';
import 'package:lantern/core/models/mapper/user_mapper.dart';
import 'package:lantern/core/updater/updater.dart';
import 'package:lantern/core/utils/pro_utils.dart';
import 'package:lantern/core/widgets/subscription_tags.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/setting/appearance.dart'
    show appearanceModeLabel, showAppearanceBottomSheet;

import '../../core/services/injection_container.dart';

enum _SettingType {
  account,
  signIn,
  vpnSetting,
  language,
  appearance,
  support,
  getPro,
  checkForUpdates,
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
    final isExpired = ref.watch(isUserExpiredProvider);
    final appSetting = ref.watch(appSettingProvider);
    final localUser = sl<LocalStorageService>().getUser();
    final localIsPro = localUser?.legacyUserData.isPro() ?? false;
    final hasProSession =
        localIsPro && (localUser?.legacyUserData.unpassRegistered ?? false);
    final isAuthenticated = appSetting.userLoggedIn || hasProSession;
    final locale = appSetting.locale;
    final themeMode = appSetting.themeMode;
    final textTheme = Theme.of(context).textTheme;
    final isUserPro = ref.watch(isUserProProvider);
    final user = ref.watch(homeProvider).value;
    String email = '';
    if (user != null) {
      email = user.legacyUserData.email;
    }
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
                label: isExpired
                    ? 'renew_pro_subscription'.i18n
                    : 'upgrade_to_pro'.i18n,
                onPressed: () {
                  appRouter.push(const Plans());
                },
              ),
            ),
          const SizedBox(height: defaultSize),
          if (appSetting.userLoggedIn)
            AppCard(
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              child: AppTile(
                label: 'account'.i18n,
                labelWidget: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('account'.i18n),
                    if (isUserPro || isExpired)
                      SubscriptionTags(
                          type: isUserPro
                              ? SubscriptionTagType.pro
                              : SubscriptionTagType.expired)
                  ],
                ),
                icon: AppImagePaths.accountSetting,
                subtitle: email.isEmpty
                    ? null
                    : Text(
                        email,
                        style: textTheme.labelMedium!.copyWith(
                          color: context.textLink,
                        ),
                      ),
                onPressed: () => settingMenuTap(_SettingType.account),
              ),
            ),
          const SizedBox(height: defaultSize),
          if (!isAuthenticated)
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
                      color: context.textLink,
                    ),
                  ),
                  onPressed: () => settingMenuTap(_SettingType.language),
                ),
                DividerSpace(),
                AppTile(
                  label: 'appearance'.i18n,
                  icon: AppImagePaths.theme,
                  trailing: Text(
                    appearanceModeLabel(themeMode),
                    style: textTheme.titleMedium!.copyWith(
                      color: context.textLink,
                    ),
                  ),
                  onPressed: () => settingMenuTap(_SettingType.appearance),
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
                if (PlatformUtils.isDesktop) ...{
                  DividerSpace(),
                  AppTile(
                    label: 'check_for_updates'.i18n,
                    icon: AppImagePaths.update,
                    onPressed: () async =>
                        await settingMenuTap(_SettingType.checkForUpdates),
                  ),
                },
                DividerSpace(),
                AppTile(
                  label: 'get_30_days_of_pro_free'.i18n,
                  icon: AppImagePaths.star,
                  onPressed: () => settingMenuTap(_SettingType.getPro),
                ),
              ],
            ),
          ),
          if (kDebugMode || AppBuildInfo.buildType == 'nightly') ...{
            SizedBox(height: defaultSize),
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
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'lantern_projects'.i18n,
              style: textTheme.labelLarge!.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Card(
            child: AppTile(
              minHeight: 72,
              icon: AppImagePaths.lanternLogoRounded,
              iconUseThemeColor: false,
              trailing: AppImage(path: AppImagePaths.outsideBrowser),
              label: 'unbounded'.i18n,
              subtitle: Text(
                'help_fight_global_internet_censorship'.i18n,
                style: textTheme.labelMedium!.copyWith(
                  color: context.textTertiary,
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
      case _SettingType.language:
        appRouter.push(Language());
        return;
      case _SettingType.appearance:
        if (PlatformUtils.isDesktop) {
          appRouter.push(const Appearance());
          return;
        }
        showAppearanceBottomSheet(context: context);
        break;
      case _SettingType.support:
        appRouter.push(Support());
        break;

      case _SettingType.getPro:
        appRouter.push(InviteFriends());
        break;
      case _SettingType.checkForUpdates:
        await checkForUpdates();
        break;

      case _SettingType.account:
        final localUser = sl<LocalStorageService>().getUser();
        if (localUser == null) {
          /// This should not happen, but just in case.
          /// If user is not account screen it mean user should have some data
          appRouter.push(const SignInEmail());
          return;
        }
        final userSignedIn = ref.read(appSettingProvider).userLoggedIn;
        final email = localUser.legacyUserData.email;
        final isPro = localUser.legacyUserData.isPro();
        if (isPro && !userSignedIn) {
          await showProAccountFlowDialog(
              context: context, hasEmail: email.isNotEmpty);
          return;
        }

        appRouter.push(Account());
        break;
      case _SettingType.vpnSetting:
        appRouter.push(VPNSetting());
        break;
      case _SettingType.browserUnbounded:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  Future<void> checkForUpdates() async {
    try {
      await sl<Updater>().checkNow();
    } catch (e, st) {
      appLogger.error('Error checking for updates: $e', st);
      AppDialog.errorDialog(
        context: context,
        title: 'error'.i18n,
        content: e.localizedDescription,
      );
    }
  }
}
