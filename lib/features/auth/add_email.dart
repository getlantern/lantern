import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/services/app_purchase.dart';

import '../../core/services/injection_container.dart';

@RoutePage(name: 'AddEmail')
class AddEmail extends HookWidget {
  final AuthFlow authFlow;

  const AddEmail({
    super.key,
    this.authFlow = AuthFlow.signUp,
  });

  @override
  Widget build(BuildContext context) {
    final emailController = useTextEditingController();
    final textTheme = Theme.of(context).textTheme;
    return BaseScreen(
      title: 'add_your_email'.i18n,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: emailController,
            label: 'email'.i18n,
            prefixIcon: AppImagePaths.email,
            hintText: 'example@gmail.com',
          ),
          SizedBox(height: defaultSize),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: defaultSize),
            child: Text('add_your_email_message'.i18n),
          ),
          SizedBox(height: 32),
          PrimaryButton(
            label: 'continue'.i18n,
            onPressed: () {
              appRouter.push(
                  ConfirmEmail(email: 'example@gmail.com', authFlow: authFlow));
            },
          ),
          SizedBox(height: defaultSize),
          DividerSpace(),
          SizedBox(height: defaultSize),
          SecondaryButton(
            label: 'continue_with_google'.i18n,
            icon: AppImagePaths.google,
            onPressed: () {},
          ),
          SizedBox(height: defaultSize),
          SecondaryButton(
            label: 'continue_with_apple'.i18n,
            icon: AppImagePaths.apple,
            onPressed: () {},
          ),
          SizedBox(height: defaultSize),
          DividerSpace(),
          SizedBox(height: defaultSize),
          Center(
            child: AppTextButton(
              label: 'continue_with_email'.i18n,
              textColor: AppColors.gray9,
              onPressed: () {
                startSub();
                // appRouter.popUntilRoot();
              },
            ),
          ),
        ],
      ),
    );
  }

  void startSub() {
    sl<AppPurchase>().startSubscription(
      plan: 'plan',
      onSuccess: (purchase) {},
      onError: (error) {},
    );
  }
}
