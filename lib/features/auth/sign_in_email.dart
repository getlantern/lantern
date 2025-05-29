import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/widgets/app_rich_text.dart';
import 'package:lantern/core/widgets/oauth_login.dart';
import 'package:lantern/features/auth/add_email.dart';

import '../../core/common/common.dart';

@RoutePage(name: 'SignInEmail')
class SignInEmail extends StatelessWidget {
  const SignInEmail({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      title: 'sign_in_to_lantern_pro'.i18n,
      body: Column(
        children: <Widget>[
          SizedBox(height: defaultSize),
          Text(
            'enter_your_lantern_pro_account_details'.i18n,
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
            label: 'sign_in_with_email'.i18n,
            onPressed: () {
              appRouter.push(SignInPassword(email: 'example@gmail.com'));
            },
          ),
          SizedBox(height: defaultSize),
          DividerSpace(),
          SizedBox(height: defaultSize),
          OAuthLogin(
            methodType: SignUpMethodType.google,
            onResult: onOAuthResult,
          ),
          SizedBox(height: defaultSize),
          OAuthLogin(
            methodType: SignUpMethodType.apple,
            onResult: onOAuthResult,
          ),
          SizedBox(height: defaultSize),
          DividerSpace(),
          SizedBox(height: 32),
          AppRichText(
            texts: 'New to Lantern? ',
            boldTexts: 'Create an account',
            boldUnderline: true,
            boldOnPressed: () {
              appRouter.push(Plans());
            },
          )
        ],
      ),
    );
  }

  void onOAuthResult(Map<String, dynamic> result) {}
}
