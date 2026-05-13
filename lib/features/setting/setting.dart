import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/localization/localization_constants.dart';
import 'package:lantern/core/updater/updater.dart';
import 'package:lantern/core/utils/pro_utils.dart';
import 'package:lantern/core/widgets/subscription_tags.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/features/plans/restore_purchase_mixin.dart';
import 'package:lantern/features/setting/appearance.dart'
    show appearanceModeLabel, showAppearanceBottomSheet;
import 'package:lantern/features/setting/unbounded_setting.dart';

import '../../core/services/injection_container.dart';

enum _SettingType {
  account,
  signIn,
  vpnSetting,
  unboundedSetting,
  language,
  appearance,
  support,
  getPro,
  checkForUpdates,
  browserUnbounded,
  restorePurchase,
}

@RoutePage(name: 'Setting')
class Setting extends StatefulHookConsumerWidget {
  const Setting({super.key});

  @override
  ConsumerState<Setting> createState() => _SettingState();
}

class _SettingState extends ConsumerState<Setting>
    with RestorePurchaseMixin<Setting> {
  late final Future<bool> _canCheckForUpdates = _canCheckForUpdatesSafely();

  Future<bool> _canCheckForUpdatesSafely() async {
    if (!sl.isRegistered<Updater>()) {
      appLogger.warning('Updater not registered, hiding update check setting');
      return false;
    }
    try {
      return await sl<Updater>().canCheckForUpdates();
    } catch (e, st) {
      appLogger.error('Failed to determine update check availability', e, st);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = ref.watch(isUserExpiredProvider);
    final user = ref.watch(homeProvider).value;
    final isUserPro = ref.watch(isUserProProvider);
    final email = ref.watch(userEmailProvider);

    final appSetting = ref.watch(appSettingProvider);
    // Server-side gate. Censored regions get Features[unbounded]=false,
    // and every Unbounded-flavoured row in this menu (the settings sub-
    // page link AND the project promo card at the bottom) disappears.
    final unboundedAvailable =
        ref.watch(featureFlagProvider).getBool(FeatureFlag.unbounded);

    final hasProSession =
        (user?.legacyUserData.isPro ?? false) &&
        (user?.legacyUserData.unpassRegistered ?? false);

    final isAuthenticated = appSetting.userLoggedIn || hasProSession;

    final locale = appSetting.locale;
    final themeMode = appSetting.themeMode;
    final textTheme = Theme.of(context).textTheme;
    final userLoggedIn = appSetting.userLoggedIn;

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
          if (userLoggedIn || isUserPro)
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
                            : SubscriptionTagType.expired,
                      ),
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
                if (unboundedAvailable) ...[
                  DividerSpace(),
                  AppTile(
                    label: 'Unbounded Settings',
                    icon: AppImagePaths.share,
                    onPressed: () =>
                        settingMenuTap(_SettingType.unboundedSetting),
                  ),
                ],
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
                FutureBuilder<bool>(
                  future: _canCheckForUpdates,
                  builder: (context, snapshot) {
                    final show =
                        PlatformUtils.isDesktop ||
                        (snapshot.connectionState == ConnectionState.done &&
                            snapshot.data == true);
                    if (!show) return const SizedBox.shrink();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DividerSpace(),
                        AppTile(
                          label: 'check_for_updates'.i18n,
                          icon: AppImagePaths.update,
                          onPressed: () async => await settingMenuTap(
                            _SettingType.checkForUpdates,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                DividerSpace(),
                AppTile(
                  label: 'get_30_days_of_pro_free'.i18n,
                  icon: AppImagePaths.star,
                  onPressed: () => settingMenuTap(_SettingType.getPro),
                ),
                if (isStoreVersion() && !isUserPro) ...[
                  DividerSpace(),
                  AppTile(
                    label: 'restore_purchase'.i18n,
                    icon: AppImagePaths.restorePurchase,
                    onPressed: () =>
                        settingMenuTap(_SettingType.restorePurchase),
                  ),
                ],
              ],
            ),
          ),
          if (AppBuildInfo.isDevModeEnabled) ...{
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
          if (unboundedAvailable) ...[
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
        final user = ref.read(homeProvider).value;
        if (user == null) {
          appRouter.push(const SignInEmail());
          return;
        }

        final userSignedIn = ref.read(appSettingProvider).userLoggedIn;
        final email = user.legacyUserData.email;
        final isPro = user.legacyUserData.isPro;
        if (isPro && !userSignedIn) {
          await showProAccountFlowDialog(
            context: context,
            hasEmail: email.isNotEmpty,
          );
          return;
        }

        appRouter.push(Account());
        break;
      case _SettingType.vpnSetting:
        appRouter.push(VPNSetting());
        break;
      case _SettingType.unboundedSetting:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UnboundedSetting()),
        );
        break;
      case _SettingType.browserUnbounded:
        // TODO: Handle this case.
        throw UnimplementedError();
      case _SettingType.restorePurchase:
        restorePurchaseFlow();
        break;
    }
  }

  Future<void> checkForUpdates() async {
    try {
      await sl<Updater>().checkNow();
    } catch (e, st) {
      appLogger.error('Error checking for updates: $e', st);
      if (!mounted) return;
      AppDialog.errorDialog(
        context: context,
        title: 'error'.i18n,
        content: e.localizedDescription,
      );
    }
  }
}
