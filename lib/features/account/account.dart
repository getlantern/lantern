import 'dart:io';

import 'package:auto_route/annotations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/plan.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/widgets/user_devices.dart';
import 'package:lantern/features/account/provider/account_notifier.dart';
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
    return BaseScreen(
      title: 'account'.i18n,
      body: _buildBody(context, ref),
    );
  }

  Widget _buildBody(BuildContext buildContext, WidgetRef ref) {
    final user = sl<LocalStorageService>().getUser();

    final appSettings = ref.read(appSettingNotifierProvider);
    final theme = Theme.of(buildContext).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(height: defaultSize),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            'lantern_pro_email'.i18n,
            style: theme.labelLarge!.copyWith(
              color: AppColors.gray8,
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
                appRouter.push(SignInPassword(
                    email: appSettings.email, fromChangeEmail: true));
              },
            ),
          ),
        ),
        SizedBox(height: defaultSize),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            user!.legacyUserData.subscriptionData.autoRenew
                ? 'subscription_renewal_date'.i18n
                : 'pro_account_expiration'.i18n,
            style: theme.labelLarge!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppTile(
            label: user.legacyUserData.toDate(),
            contentPadding: EdgeInsets.only(left: 16),
            icon: AppImagePaths.autoRenew,
            trailing: AppTextButton(
              label: 'manage_subscription'.i18n,
              onPressed: () => onManageSubscriptionTap(ref, buildContext),
            ),
          ),
        ),
        SizedBox(height: defaultSize),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            'lantern_pro_devices'.i18n,
            style: theme.labelLarge!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        UserDevices(),
        Spacer(),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            'danger_zone'.i18n,
            style: theme.labelLarge!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        Card(
          child: AppTile(
            contentPadding: EdgeInsets.only(left: 16),
            icon: AppImagePaths.delete,
            label: 'delete_account'.i18n,
            trailing: AppTextButton(
              label: 'delete'.i18n,
              textColor: AppColors.red7,
              onPressed: _onDeleteTap,
            ),
          ),
        ),
        SizedBox(height: defaultSize),
      ],
    );
  }

  void _onDeleteTap() {
    appRouter.push(const DeleteAccount());
  }

  Future<void> onManageSubscriptionTap(
      WidgetRef ref, BuildContext buildContext) async {
    switch (Platform.operatingSystem) {
      case "android":
        if (isStoreVersion()) {
          /// user is using play store version
          openGooglePlaySubscriptions();
          return;
        }
        stripeBillingPortal(ref, buildContext);
        break;
      case "ios":
        ref.read(accountNotifierProvider.notifier).openAppleSubscriptions();
        break;
      case "macos":
      case "linux":
      case "windows":

        /// user is using desktop version
        stripeBillingPortal(ref, buildContext);
        break;
    }
  }

  Future<void> openGooglePlaySubscriptions() async {
    UrlUtils.openUrl("https://play.google.com/store/account/subscriptions");
  }

  void openAppleSubscriptions(WidgetRef ref) async {}

  Future<void> stripeBillingPortal(
      WidgetRef ref, BuildContext buildContext) async {
    try {
      buildContext.showLoadingDialog();
      final result =
          await ref.read(lanternServiceProvider).stripeBillingPortal();
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
      WidgetRef ref, BuildContext context) async {
    try {
      context.showLoadingDialog();
      appLogger.info('Checking subscription after stripe portal');
      final oldUser = sl<LocalStorageService>().getUser()!;
      final lanternService = ref.read(lanternServiceProvider);
      final notifier = ref.read(homeNotifierProvider.notifier);

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

  Future<void> _handleSubscriptionChange(
      {required UserResponse oldUser,
      required LanternService lanternService,
      required HomeNotifier notifier,
      required BuildContext context}) async {
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
          final isCancelled = !isPro ||
              (oldUser.legacyUserData.subscriptionData.autoRenew &&
                  newUser.legacyUserData.subscriptionData.autoRenew == false);

          final isRenew =
              (oldUser.legacyUserData.subscriptionData.autoRenew == false &&
                  newUser.legacyUserData.subscriptionData.autoRenew);

          if (isRenew) {
            appLogger
                .info('User renewed subscription: $oldPlanId → $newPlanId');
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
            appLogger
                .info('User cancelled subscription. Previous plan: $oldPlanId');
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
}
