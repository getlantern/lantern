import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/user_devices.dart';

@RoutePage(name: 'Account')
class Account extends StatelessWidget {
  const Account({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'account'.i18n,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext buildContext) {
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
                label: 'manage_subscription'.i18n, onPressed: () {}),
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
}



