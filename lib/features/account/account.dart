import 'package:auto_route/annotations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/plan.dart';
import 'package:lantern/core/extensions/user_data.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/core/widgets/user_devices.dart';
import 'package:lantern/features/account/provider/account_notifier.dart';
import 'package:lantern/core/keys/app_keys.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/home_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/lantern/protos/protos/auth.pb.dart';

@RoutePage(name: 'Account')
class Account extends HookConsumerWidget {
  const Account({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettings = ref.watch(appSettingProvider);

    return BaseScreen(
      title: 'account'.i18n,
      appBar: CustomAppBar(
        title: Text('account'.i18n),
        actions: [
          if (appSettings.userLoggedIn)
            AppTextButton(
              key: AuthKeys.accountLogoutActionButton,
              label: 'logout'.i18n,
              textColor: context.textLink,
              onPressed: () => logoutDialog(context, ref),
            ),
        ],
      ),
      body: _buildBody(context, ref),
    );
  }

  Widget _buildBody(BuildContext buildContext, WidgetRef ref) {
    final user = ref.watch(homeProvider).value;
    final isExpired = ref.watch(isUserExpiredProvider);
    final isPro = ref.watch(isUserProProvider);
    final appSettings = ref.watch(appSettingProvider);
    final isUserFree = !isExpired && !isPro;
    final theme = TextTheme.of(buildContext);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isUserFree)
            ProButton(
              onPressed: () {
                appRouter.push(const Plans());
              },
            ),
          if (isExpired) ...{
            InfoRow(
              minTileHeight: 40,
              backgroundColor: buildContext.statusErrorBg,
              borderColor: buildContext.statusErrorBorder,
              textStyle: theme.labelLarge!.copyWith(
                color: buildContext.statusErrorText,
              ),
              text: 'pro_subscription_expired_message'.i18n,
            ),
            SizedBox(height: defaultSize),
            ProButton(
              label: 'renew_pro_subscription'.i18n,
              onPressed: () {
                appRouter.push(const Plans());
              },
            ),
          },
          SizedBox(height: defaultSize),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              isUserFree ? 'lantern_email'.i18n : 'lantern_pro_email'.i18n,
              style: theme.labelLarge!.copyWith(
                color: buildContext.textSecondary,
              ),
            ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: AppTile(
              label: appSettings.email.toLowerCase(),
              icon: AppImagePaths.email,
              contentPadding: EdgeInsets.only(left: 16),
              onPressed: kDebugMode
                  ? () {
                      copyToClipboard(appSettings.email);
                    }
                  : null,
              trailing: AppTextButton(
                label: 'change_email'.i18n,
                onPressed: () {
                  appRouter.push(
                    SignInPassword(
                      email: appSettings.email,
                      fromChangeEmail: true,
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: defaultSize),
          if (isExpired)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'last_subscription_renewal_date'.i18n,
                style: theme.labelLarge!.copyWith(
                  color: buildContext.textSecondary,
                ),
              ),
            )
          else if (isPro)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                user!.legacyUserData.subscriptionData.autoRenew
                    ? 'subscription_renewal_date'.i18n
                    : 'pro_account_expiration'.i18n,
                style: theme.labelLarge!.copyWith(
                  color: buildContext.textSecondary,
                ),
              ),
            ),
          if (!isUserFree)
            AppCard(
              padding: EdgeInsets.zero,
              child: AppTile(
                label: user!.legacyUserData.toDate(),
                contentPadding: EdgeInsets.only(left: 16),
                icon: AppImagePaths.autoRenew,
                trailing: planTrailingWidget(user, buildContext, ref),
              ),
            ),
          if (isPro && user!.legacyUserData.devices.toList().isNotEmpty) ...[
            SizedBox(height: defaultSize),
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                'lantern_pro_devices'.i18n,
                style: theme.labelLarge!.copyWith(
                  color: buildContext.textSecondary,
                ),
              ),
            ),
            UserDevices(),
          ],
          SizedBox(height: defaultSize),
          Spacer(),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              'danger_zone'.i18n,
              style: theme.labelLarge!.copyWith(
                color: buildContext.textSecondary,
              ),
            ),
          ),
          Card(
            child: AppTile(
              contentPadding: EdgeInsets.only(left: 16),
              icon: AppImagePaths.delete,
              iconUseThemeColor: false,
              label: 'delete_account'.i18n,
              trailing: AppTextButton(
                key: AuthKeys.accountDeleteActionButton,
                label: 'delete'.i18n,
                textColor: buildContext.statusErrorText,
                onPressed: _onDeleteTap,
              ),
            ),
          ),
          SizedBox(height: size24),
        ],
      ),
    );
  }

  Widget? planTrailingWidget(
    UserResponse user,
    BuildContext buildContext,
    WidgetRef ref,
  ) {
    final autoRenew = user.legacyUserData.subscriptionData.autoRenew;
    final isUserExpired = user.legacyUserData.userLevel == 'expired';
    final isUserPro = user.legacyUserData.isPro;

    ///User has an active subscription with auto-renew enabled
    if (!isUserExpired && autoRenew) {
      return AppTextButton(
        label: 'manage_subscription'.i18n,
        onPressed: () => onManageSubscriptionTap(ref, buildContext, user),
      );
    }
    if (isUserPro && !autoRenew) {
      return AppTextButton(label: 'renew'.i18n, onPressed: onRenewTap);
    }

    return null;
  }

  void _onDeleteTap() {
    appRouter.push(const DeleteAccount());
  }

  Future<void> onManageSubscriptionTap(
    WidgetRef ref,
    BuildContext buildContext,
    UserResponse user,
  ) async {
    final provider = user.legacyUserData.subscriptionData.provider;
    switch (provider) {
      case 'apple':
        if (PlatformUtils.isIOS) {
          ref.read(accountProvider.notifier).openAppleSubscriptions();
          return;
        }
        AppDialog.dialog(
          context: buildContext,
          title: 'manage_subscription'.i18n,
          content: 'manage_subscription_apple_app_store'.i18n,
        );

        return;
      case 'googleplay':
        if (PlatformUtils.isAndroid) {
          openGooglePlaySubscriptions();
          return;
        }
        AppDialog.dialog(
          context: buildContext,
          title: 'manage_subscription'.i18n,
          content: 'manage_subscription_google_play'.i18n,
        );

        break;
      case 'stripe':

        /// No matter user is using desktop or mobile, if the provider is stripe, open billing portal
        stripeBillingPortal(ref, buildContext);
        break;
    }
  }

  void onRenewTap() {
    /// Most user renewal attempts are one-time purchases.
    /// Send the user to the plans page.
    appRouter.push(const Plans());
  }

  Future<void> openGooglePlaySubscriptions() async {
    UrlUtils.openUrl("https://play.google.com/store/account/subscriptions");
  }

  Future<void> stripeBillingPortal(
    WidgetRef ref,
    BuildContext buildContext,
  ) async {
    try {
      buildContext.showLoadingDialog();
      final result = await ref
          .read(lanternServiceProvider)
          .stripeBillingPortal();
      result.fold(
        (failure) {
          buildContext.hideLoadingDialog();
          appLogger.error('Error on manage subscription tap', failure);
          buildContext.showSnackBar(failure.localizedErrorMessage);
        },
        (stripeUrl) {
          buildContext.hideLoadingDialog();
          UrlUtils.openWebview(
            stripeUrl,
            onWebviewResult: (p0) {
              checkSubscriptionAfterStripe(ref, buildContext);
            },
          );
        },
      );
    } catch (e) {
      appLogger.error('Error on manage subscription tap', e);
    }
  }

  Future<void> checkSubscriptionAfterStripe(
    WidgetRef ref,
    BuildContext context,
  ) async {
    try {
      context.showLoadingDialog();
      appLogger.info('Checking subscription after stripe portal');
      final oldUser = ref.read(homeProvider).value!;
      final lanternService = ref.read(lanternServiceProvider);
      final notifier = ref.read(homeProvider.notifier);

      await _handleSubscriptionChange(
        oldUser: oldUser,
        lanternService: lanternService,
        notifier: notifier,
        context: context,
      );
    } catch (e) {
      appLogger.error('Exception during subscription check', e);
    } finally {
      context.hideLoadingDialog();
    }
  }

  Future<void> _handleSubscriptionChange({
    required UserResponse oldUser,
    required LanternService lanternService,
    required HomeNotifier notifier,
    required BuildContext context,
  }) async {
    final delays = [Duration(seconds: 1), Duration(seconds: 2)];
    for (final delay in delays) {
      appLogger.info('Checking subscription with delay: $delay');
      if (delay != Duration.zero) await Future.delayed(delay);

      final result = await lanternService.fetchUserData();
      final shouldStop = result.fold(
        (failure) {
          appLogger.error('Subscription check error', failure);
          return;
        },
        (newUser) {
          final oldPlanId = oldUser.legacyUserData.subscriptionData.planID;
          final newPlanId = newUser.legacyUserData.subscriptionData.planID;
          final isPro = newUser.legacyUserData.userLevel == 'pro';
          final isPlanChanged = isPro && oldPlanId != newPlanId;
          final isCancelled =
              !isPro ||
              (oldUser.legacyUserData.subscriptionData.autoRenew &&
                  newUser.legacyUserData.subscriptionData.autoRenew == false);

          final isRenew =
              (oldUser.legacyUserData.subscriptionData.autoRenew == false &&
              newUser.legacyUserData.subscriptionData.autoRenew);

          if (isRenew) {
            appLogger.info(
              'User renewed subscription: $oldPlanId → $newPlanId',
            );
            notifier.updateUserData(newUser);
            context.showSnackBar('subscription_renewed'.i18n);
            return true;
          }

          if (isPlanChanged) {
            appLogger.info('User changed plan: $oldPlanId → $newPlanId');
            notifier.updateUserData(newUser);
            context.showSnackBar('subscription_updated'.i18n);
            return true;
          }

          if (isCancelled) {
            appLogger.info(
              'User cancelled subscription. Previous plan: $oldPlanId',
            );
            notifier.updateUserData(newUser);
            context.showSnackBar('subscription_cancelled'.i18n);
            return true;
          }
          return false;
        },
      );
      if (shouldStop ?? false) {
        break;
      }
    }
  }

  void logoutDialog(BuildContext context, WidgetRef ref) {
    final theme = TextTheme.of(context);
    final isExpired = ref.read(isUserExpiredProvider);
    AppDialog.customDialog(
      context: context,
      action: [
        AppTextButton(
          label: 'not_now'.i18n,
          textColor: context.textSecondary,
          onPressed: () {
            appRouter.pop();
          },
        ),
        AppTextButton(
          key: AuthKeys.accountLogoutConfirmButton,
          label: 'logout'.i18n,
          onPressed: () {
            onLogout(context, ref);
            appRouter.pop();
          },
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(height: defaultSize),
          Text('logout'.i18n, style: theme.headlineSmall),
          SizedBox(height: defaultSize),
          Text(
            isExpired ? 'logout_message_expired'.i18n : 'logout_message'.i18n,
            style: theme.bodyMedium!.copyWith(color: context.textPrimary),
          ),
        ],
      ),
    );
  }

  Future<void> onLogout(BuildContext context, WidgetRef ref) async {
    context.showLoadingDialog();
    final appSetting = ref.read(appSettingProvider);
    final result = await ref
        .read(lanternServiceProvider)
        .logout(appSetting.email);
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
