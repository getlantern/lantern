import 'dart:io';

import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/utils/store_utils.dart';
import 'package:lantern/core/widgets/user_devices.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

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
        Card(
          child: AppTile(
            label: '122300984@qq.com',
            icon: AppImagePaths.email,
            onPressed: () {},
          ),
        ),
        SizedBox(height: defaultSize),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(
            'pro_account_expiration'.i18n,
            style: theme.labelLarge!.copyWith(
              color: AppColors.gray8,
            ),
          ),
        ),
        Card(
          child: AppTile(
            label: '12/23/26',
            contentPadding: EdgeInsets.only(left: 16),
            icon: AppImagePaths.email,
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
        if (sl<StoreUtils>().isPlayStoreVersion) {
          /// user is using play store version
          openGooglePlaySubscriptions();
          return;
        }
        stripeBillingPortal(ref, buildContext);
        break;
      case "ios":
        // openAppleSubscriptions(ref);
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

  void openAppleSubscriptions(WidgetRef ref) async {
    UrlUtils.openUrl("https://apps.apple.com/account/subscriptions");
  }

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
          buildContext.showSnackBarError(failure.localizedErrorMessage);
        },
        (stripeUrl) {
          buildContext.hideLoadingDialog();
          UrlUtils.openWebview(stripeUrl);
        },
      );
    } catch (e) {
      appLogger.error('Error on manage subscription tap', e);
    }
  }
}
