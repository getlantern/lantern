import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../core/common/common.dart';

@RoutePage(name: 'ResetPasswordEmail')
class ResetPasswordEmail extends StatelessWidget {
  const ResetPasswordEmail({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'reset_your_password'.i18n,
      body: Column(
        children: <Widget>[
          SizedBox(height: defaultSize),
          Text(
            'enter_your_lantern_pro_account_email'.i18n,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: defaultSize),
          AppTextField(
            hintText: '',
            prefixIcon: AppImagePaths.email,
            label: 'email'.i18n,

            onChanged: (value) {},
          ),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'next'.i18n,
            onPressed: () {
              appRouter.push(ConfirmEmail(
                email: 'example@getlantern.org',
                authFlow: AuthFlow.resetPassword,
              ));
            },
          ),
        ],
      ),
    );
  }
}
