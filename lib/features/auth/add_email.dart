import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:lantern/core/common/app_text_field.dart';
import 'package:lantern/core/common/common.dart';

@RoutePage(name: 'AddEmail')
class AddEmail extends HookWidget {
  const AddEmail({super.key});

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
            padding: defaultPadding,
            child: Text('add_your_email_message'.i18n),
          ),
          SizedBox(height: defaultSize),
          PrimaryButton(
            label: 'continue'.i18n,
            onPressed: () {},
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
                appRouter.push(ConfirmEmail());
              },
            ),
          ),
        ],
      ),
    );
  }
}
